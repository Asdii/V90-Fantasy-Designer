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
  const Esp32Position({
    required this.xMm,
    required this.receivedAt,
    this.bootId,
    this.referenceId,
    this.referenceRevision,
  });
  final double xMm;
  final DateTime receivedAt;
  final String? bootId;
  final String? referenceId;
  final int? referenceRevision;
}

class Esp32Status {
  const Esp32Status({
    required this.state,
    this.message,
    this.endpoint,
    this.deviceStatus,
    this.reconnectAttempt = 0,
    this.deviceId,
    this.bootId,
    this.referenceId,
    this.referenceRevision,
    this.supportsXReference = false,
  });
  final Esp32ConnectionState state;
  final String? message;
  final Uri? endpoint;
  final String? deviceStatus;
  final int reconnectAttempt;
  final String? deviceId;
  final String? bootId;
  final String? referenceId;
  final int? referenceRevision;
  final bool supportsXReference;
  bool get isConnected => state == Esp32ConnectionState.connected;
}

/// Optional capability. Assigns a coordinate only after an explicit physical
/// user confirmation; never controls or moves an axis.
abstract interface class XReferenceEsp32Service {
  Future<XReferenceAck> setXReference({
    required String bootId,
    required String referenceId,
    required double xMm,
  });
}

class XReferenceAck {
  const XReferenceAck({
    required this.bootId,
    required this.referenceId,
    required this.revision,
    required this.xMm,
  });
  final String bootId;
  final String referenceId;
  final int revision;
  final double xMm;
}
