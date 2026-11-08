import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'esp32_protocol.dart';
import 'esp32_device.dart';
import 'esp32_service.dart';

class WebSocketEsp32Service implements Esp32Service, XReferenceEsp32Service {
  WebSocketEsp32Service({
    this.allowZeroX = false,
    this.resolver,
    String? deviceId,
    this.connectTimeout = const Duration(seconds: 5),
    this.telemetryTimeout = const Duration(seconds: 10),
    this.pingInterval = const Duration(seconds: 5),
    this.reconnectDelay = const Duration(seconds: 1),
    this.maxReconnectDelay = const Duration(seconds: 5),
  }) : _deviceId = deviceId {
    if ([
      connectTimeout,
      telemetryTimeout,
      pingInterval,
      reconnectDelay,
      maxReconnectDelay,
    ].any((d) => d <= Duration.zero)) {
      throw ArgumentError('All timeout and backoff durations must be positive');
    }
  }

  final bool allowZeroX;
  final Esp32EndpointResolver? resolver;
  String? _deviceId, _candidateId;
  bool _identityConfirmed = false;
  String? _bootId, _referenceId;
  int? _referenceRevision;
  bool _supportsXReference = false;
  _PendingReference? _referenceRequest;
  final Duration connectTimeout;
  final Duration telemetryTimeout;
  final Duration pingInterval;
  final Duration reconnectDelay;
  final Duration maxReconnectDelay;
  final _positions = StreamController<Esp32Position>.broadcast();
  final _statuses = StreamController<Esp32Status>.broadcast();
  Esp32Position? _position;
  Esp32Status _status = const Esp32Status(
    state: Esp32ConnectionState.disconnected,
  );
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retryTimer;
  Timer? _telemetryTimer;
  Uri? _endpoint;
  bool _disposed = false;
  bool _wanted = false;
  int _generation = 0;
  int _attempt = 0;

  @override
  Stream<Esp32Position> get positionStream => _positions.stream;
  @override
  Stream<Esp32Status> get statusStream => _statuses.stream;
  @override
  Esp32Position? get currentPosition => _position;
  @override
  Esp32Status get currentStatus => _status;

  @override
  Future<void> connect([Uri? endpoint]) async {
    if (_disposed) throw StateError('WebSocketEsp32Service is disposed');
    final target = endpoint ?? _endpoint;
    if (target == null) throw ArgumentError('A WebSocket endpoint is required');
    validateEsp32Endpoint(target);
    // Invalidate old callbacks before awaiting anything.
    final generation = ++_generation;
    _wanted = true;
    _endpoint = target;
    _attempt = 0;
    _position = null;
    resolver?.cancel();
    _cancelTimers();
    await _closeSocket();
    if (!_active(generation)) return;
    await _open(generation);
  }

  bool _active(int generation) =>
      !_disposed && _wanted && generation == _generation;

  Future<void> _open(int generation) async {
    if (!_active(generation)) return;
    _emit(
      _attempt == 0
          ? Esp32ConnectionState.connecting
          : Esp32ConnectionState.reconnecting,
    );
    // timeout() alone does not cancel the underlying handshake. Close any late
    // result so a timed-out or stopped attempt cannot leak a live connection.
    try {
      _identityConfirmed = false;
      _bootId = null;
      _referenceId = null;
      _referenceRevision = null;
      _supportsXReference = false;
      _candidateId = _deviceId;
      if (resolver != null) {
        final device = await resolver!.resolve(_endpoint!, deviceId: _deviceId);
        if (!_active(generation)) return;
        if (device == null) throw const SocketException('Machine not found');
        _endpoint = device.endpoint;
        _candidateId = _deviceId ?? device.id;
      }
      var expired = false;
      final pending = WebSocket.connect(
        _endpoint.toString(),
        compression: CompressionOptions.compressionOff,
      );
      unawaited(
        pending.then<void>((socket) {
          if (expired || !_active(generation)) unawaited(_closeQuietly(socket));
        }, onError: (Object _, StackTrace _) {}),
      );
      final socket = await pending.timeout(
        connectTimeout,
        onTimeout: () {
          expired = true;
          throw TimeoutException('ESP32 connection timed out');
        },
      );
      if (!_active(generation)) {
        await _closeQuietly(socket);
        return;
      }
      _socket = socket;
      socket.pingInterval = pingInterval;
      // A transport handshake does not confirm the encoder is available.
      _position = null;
      _emit(
        Esp32ConnectionState.connecting,
        message: 'Awaiting ESP32 telemetry',
      );
      _armTelemetryTimeout(generation, socket);
      _subscription = socket.listen(
        (dynamic message) => _receive(message, generation, socket),
        onError: (Object error) =>
            _lost(generation, socket, 'WebSocket connection failed'),
        onDone: () => _lost(generation, socket, 'ESP32 disconnected'),
        cancelOnError: true,
      );
    } catch (_) {
      if (_active(generation)) {
        _scheduleRetry(generation, 'Cannot connect to ESP32');
      }
    }
  }

  void _receive(Object? message, int generation, WebSocket socket) {
    if (!_active(generation) || !identical(socket, _socket)) return;
    try {
      final telemetry = Esp32Telemetry.decode(message);
      if (telemetry.deviceId != null) {
        if (_candidateId != null && telemetry.deviceId != _candidateId) {
          _lost(generation, socket, 'La dirección pertenece a otra máquina');
          return;
        }
        _deviceId = telemetry.deviceId;
        _candidateId = _deviceId;
        _identityConfirmed = true;
      }
      // The new firmware identifies itself before its first position. A stale
      // DNS/HTTP result must not allow telemetry from a different board.
      if (_candidateId != null && !_identityConfirmed) return;
      if (telemetry.isReferenceAck) {
        _receiveReferenceAck(telemetry);
        return;
      }
      if (!_applyReferenceMetadata(telemetry)) return;
      _attempt = 0; // Only valid telemetry resets backoff.
      _armTelemetryTimeout(generation, socket);
      if (telemetry.connected == false) {
        // Invalidation takes precedence over an optional x_mm in this frame.
        // Keep the transport open so a new position/true status can recover it.
        _position = null;
        _emit(
          Esp32ConnectionState.disconnected,
          message: 'ESP32 reports disconnected',
          deviceStatus: telemetry.status,
        );
        return;
      }
      final state = telemetry.xMm != null || telemetry.connected == true
          ? Esp32ConnectionState.connected
          : _status.state;
      if (telemetry.xMm != null) {
        _position = Esp32Position(
          xMm: telemetry.xMm!,
          receivedAt: DateTime.now(),
          bootId: telemetry.bootId,
          referenceId: telemetry.referenceId,
          referenceRevision: telemetry.referenceRevision,
        );
        _positions.add(_position!);
      }
      _emit(state, deviceStatus: telemetry.status ?? _status.deviceStatus);
    } on FormatException catch (error) {
      _emit(
        _status.state,
        message: 'Invalid telemetry: ${error.message}',
        deviceStatus: _status.deviceStatus,
      );
    }
  }

  void _armTelemetryTimeout(int generation, WebSocket socket) {
    _telemetryTimer?.cancel();
    _telemetryTimer = Timer(
      telemetryTimeout,
      () => _lost(generation, socket, 'ESP32 telemetry timed out'),
    );
  }

  void _lost(int generation, WebSocket socket, String message) {
    if (!_active(generation) || !identical(socket, _socket)) return;
    unawaited(_closeSocket());
    _scheduleRetry(generation, message);
  }

  void _scheduleRetry(int generation, String message) {
    if (!_active(generation) || _retryTimer != null) return;
    _telemetryTimer?.cancel();
    final delayMs = math.min(
      maxReconnectDelay.inMilliseconds,
      reconnectDelay.inMilliseconds * (1 << math.min(_attempt, 20)),
    );
    _attempt++;
    _position = null;
    _emit(Esp32ConnectionState.reconnecting, message: message);
    _retryTimer = Timer(Duration(milliseconds: delayMs), () {
      _retryTimer = null;
      unawaited(_open(generation));
    });
  }

  void _emit(
    Esp32ConnectionState state, {
    String? message,
    String? deviceStatus,
  }) {
    if (_disposed) return;
    _status = Esp32Status(
      state: state,
      endpoint: _endpoint,
      message: message,
      deviceStatus: deviceStatus,
      reconnectAttempt: _attempt,
      deviceId: _deviceId,
      bootId: _bootId,
      referenceId: _referenceId,
      referenceRevision: _referenceRevision,
      supportsXReference: _supportsXReference,
    );
    _statuses.add(_status);
  }

  // Ordered WS frames can still include samples generated before a command.
  // Never let an older reference revision move the UI back into an old frame.
  bool _applyReferenceMetadata(Esp32Telemetry value) {
    if (value.bootId != null) {
      if (_bootId == value.bootId &&
          _referenceRevision != null &&
          value.referenceRevision! < _referenceRevision!) {
        return false;
      }
      if (_bootId != null && _bootId != value.bootId) {
        _failReference('La máquina se reinició. Confirma de nuevo el tope.');
        _position = null;
      }
      _bootId = value.bootId;
      _referenceId = value.referenceId;
      _referenceRevision = value.referenceRevision;
    }
    _supportsXReference = value.supportsXReference ?? _supportsXReference;
    return true;
  }

  @override
  Future<XReferenceAck> setXReference({
    required String bootId,
    required String referenceId,
    required double xMm,
  }) async {
    validateXReference(bootId, referenceId, xMm);
    final socket = _socket;
    if (_disposed ||
        !_status.isConnected ||
        socket == null ||
        socket.readyState != WebSocket.open ||
        !_supportsXReference ||
        _bootId != bootId) {
      throw StateError(
        'Conecta la máquina y actualiza su firmware para fijar X.',
      );
    }
    if (_referenceRequest != null) {
      throw StateError('Ya se está confirmando X.');
    }
    final request = _PendingReference(
      '${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(0x7fffffff)}',
      bootId,
      referenceId,
      xMm,
    );
    _referenceRequest = request;
    try {
      socket.add(
        jsonEncode({
          'type': 'set_x_reference',
          'request_id': request.id,
          'boot_id': bootId,
          'reference_id': referenceId,
          'x_mm': xMm,
        }),
      );
      return await request.result.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException(
          'No llegó la confirmación. Mantén la mesa en el tope y vuelve a confirmar.',
        ),
      );
    } finally {
      if (identical(_referenceRequest, request)) _referenceRequest = null;
    }
  }

  void _receiveReferenceAck(Esp32Telemetry telemetry) {
    final pending = _referenceRequest;
    // Ignore unsolicited/late acknowledgements: they are not user actions.
    if (pending == null || telemetry.requestId != pending.id) return;
    if (telemetry.accepted != true) {
      _failReference(
        'No se confirmó X: ${telemetry.error ?? 'reintenta en el tope'}.',
      );
      return;
    }
    if (telemetry.bootId != pending.bootId ||
        telemetry.referenceId != pending.referenceId ||
        (telemetry.xMm! - pending.xMm).abs() > 0.000001 ||
        !_applyReferenceMetadata(telemetry)) {
      _failReference('La referencia cambió durante la confirmación.');
      return;
    }
    _position = Esp32Position(
      xMm: telemetry.xMm!,
      receivedAt: DateTime.now(),
      bootId: telemetry.bootId,
      referenceId: telemetry.referenceId,
      referenceRevision: telemetry.referenceRevision,
    );
    _emit(Esp32ConnectionState.connected, deviceStatus: _status.deviceStatus);
    _positions.add(_position!);
    _referenceRequest = null;
    pending.result.complete(
      XReferenceAck(
        bootId: telemetry.bootId!,
        referenceId: telemetry.referenceId!,
        revision: telemetry.referenceRevision!,
        xMm: telemetry.xMm!,
      ),
    );
  }

  void _failReference(String reason) {
    final pending = _referenceRequest;
    _referenceRequest = null;
    if (pending != null && !pending.result.isCompleted) {
      pending.result.completeError(StateError(reason));
    }
  }

  @override
  Future<void> zeroX() async {
    if (_disposed) throw StateError('WebSocketEsp32Service is disposed');
    if (!allowZeroX) throw UnsupportedError('zero_x is disabled');
    final socket = _socket;
    if (socket == null ||
        socket.readyState != WebSocket.open ||
        !_status.isConnected) {
      throw StateError('ESP32 is not connected');
    }
    socket.add(jsonEncode({'type': 'zero_x'}));
  }

  @override
  Future<void> disconnect() async {
    if (_disposed) return;
    _wanted = false;
    resolver?.cancel();
    _generation++;
    _cancelTimers();
    _position = null;
    _emit(Esp32ConnectionState.disconnected);
    await _closeSocket();
  }

  void _cancelTimers() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
  }

  Future<void> _closeSocket() async {
    _failReference('Se perdió la conexión antes de confirmar X.');
    final subscription = _subscription;
    final socket = _socket;
    _subscription = null;
    _socket = null;
    if (subscription != null) await subscription.cancel();
    if (socket != null) await _closeQuietly(socket);
  }

  static Future<void> _closeQuietly(WebSocket socket) async {
    try {
      await socket
          .close(WebSocketStatus.goingAway)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      /* Closing is best-effort on a failed network. */
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await disconnect();
    await resolver?.dispose();
    _disposed = true;
    await Future.wait([_positions.close(), _statuses.close()]);
  }
}

class _PendingReference {
  _PendingReference(this.id, this.bootId, this.referenceId, this.xMm);
  final String id, bootId, referenceId;
  final double xMm;
  final result = Completer<XReferenceAck>();
}
