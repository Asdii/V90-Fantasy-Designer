import 'dart:async';
import 'esp32_service.dart';

/// Browser builds deliberately use MockEsp32Service for preview.
class WebSocketEsp32Service implements Esp32Service {
  WebSocketEsp32Service({
    this.allowZeroX = false,
    this.connectTimeout = const Duration(seconds: 5),
    this.telemetryTimeout = const Duration(seconds: 10),
    this.pingInterval = const Duration(seconds: 5),
    this.reconnectDelay = const Duration(seconds: 1),
    this.maxReconnectDelay = const Duration(seconds: 30),
  });
  final bool allowZeroX;
  final Duration connectTimeout,
      telemetryTimeout,
      pingInterval,
      reconnectDelay,
      maxReconnectDelay;
  final _statuses = StreamController<Esp32Status>.broadcast();
  bool _disposed = false;
  Esp32Status _status = const Esp32Status(
    state: Esp32ConnectionState.unsupported,
    message: 'Use MockEsp32Service in web preview',
  );
  @override
  Stream<Esp32Position> get positionStream => const Stream.empty();
  @override
  Stream<Esp32Status> get statusStream => _statuses.stream;
  @override
  Esp32Position? get currentPosition => null;
  @override
  Esp32Status get currentStatus => _status;
  @override
  Future<void> connect([Uri? endpoint]) async {
    if (_disposed) throw StateError('WebSocketEsp32Service is disposed');
    _status = Esp32Status(
      state: Esp32ConnectionState.unsupported,
      endpoint: endpoint,
      message: 'Native WebSocket unavailable; use simulation',
    );
    _statuses.add(_status);
  }

  @override
  Future<void> disconnect() async {}
  @override
  Future<void> zeroX() async =>
      throw UnsupportedError('Native WebSocket unavailable');
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _statuses.close();
  }
}
