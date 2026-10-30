import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'esp32_protocol.dart';
import 'esp32_service.dart';

class WebSocketEsp32Service implements Esp32Service {
  WebSocketEsp32Service({
    this.allowZeroX = false,
    this.connectTimeout = const Duration(seconds: 5),
    this.telemetryTimeout = const Duration(seconds: 10),
    this.pingInterval = const Duration(seconds: 5),
    this.reconnectDelay = const Duration(seconds: 1),
    this.maxReconnectDelay = const Duration(seconds: 30),
  }) {
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
    try {
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
    );
    _statuses.add(_status);
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
    _disposed = true;
    await Future.wait([_positions.close(), _statuses.close()]);
  }
}
