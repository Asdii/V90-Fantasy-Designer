/// Read-only telemetry connection. No motion or job execution API is exposed.
abstract interface class Esp32Service {
  Stream<Esp32Position> get positionStream;
  Stream<Esp32Status> get statusStream;

  /// Native connections clear this on loss or `connected: false`. Status-only
  /// recovery never recreates or republishes a stale position.
  Esp32Position? get currentPosition;
  Esp32Status get currentStatus;
  Future<void> connect([Uri? endpoint]);
  Future<void> disconnect();

  /// Explicit opt-in only; callers must invoke this from a user action.
  Future<void> zeroX();
  Future<void> dispose();
}

enum Esp32ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  unsupported,
  error,
}

class Esp32Position {
  const Esp32Position({required this.xMm, required this.receivedAt});
  final double xMm;
  final DateTime receivedAt;
}

class Esp32Status {
  const Esp32Status({
    required this.state,
    this.message,
    this.endpoint,
    this.deviceStatus,
    this.reconnectAttempt = 0,
  });
  final Esp32ConnectionState state;
  final String? message;
  final Uri? endpoint;
  final String? deviceStatus;
  final int reconnectAttempt;
  bool get isConnected => state == Esp32ConnectionState.connected;
}
