import 'dart:async';
import 'dart:math' as math;

import 'esp32_service.dart';

class MockEsp32Service implements Esp32Service {
  MockEsp32Service({
    double initialPositionMm = 0,
    this.telemetryInterval = const Duration(milliseconds: 100),
  }) {
    _checkPosition(initialPositionMm);
    if (telemetryInterval <= Duration.zero) {
      throw ArgumentError('telemetryInterval must be positive');
    }
    _position = Esp32Position(
      xMm: initialPositionMm,
      receivedAt: DateTime.now(),
    );
  }

  final Duration telemetryInterval;
  final _positions = StreamController<Esp32Position>.broadcast();
  final _statuses = StreamController<Esp32Status>.broadcast();
  Esp32Position? _position;
  Esp32Status _status = const Esp32Status(
    state: Esp32ConnectionState.disconnected,
    message: 'Simulation stopped',
  );
  Timer? _timer;
  Timer? _heartbeat;
  bool _disposed = false;

  @override
  Stream<Esp32Position> get positionStream => _positions.stream;
  @override
  Stream<Esp32Status> get statusStream => _statuses.stream;
  @override
  Esp32Position? get currentPosition => _position;
  @override
  Esp32Status get currentStatus => _status;
  bool get isSimulating => _timer?.isActive ?? false;

  @override
  Future<void> connect([Uri? endpoint]) async {
    _checkAlive();
    _status = Esp32Status(
      state: Esp32ConnectionState.connected,
      endpoint: endpoint,
      message: 'Simulated encoder',
      deviceStatus: 'simulation',
    );
    _statuses.add(_status);
    _positions.add(_position!);
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(telemetryInterval, (_) {
      if (!isSimulating) _emitPosition(_position!.xMm);
    });
  }

  /// Manual slider input. Cancels automatic updates so the user keeps control.
  void setPosition(double xMm) {
    _checkAlive();
    _checkPosition(xMm);
    stopSimulation();
    _emitPosition(xMm);
  }

  void startSimulation({
    double minMm = 0,
    double maxMm = 20,
    Duration period = const Duration(seconds: 8),
    Duration interval = const Duration(milliseconds: 50),
  }) {
    _checkAlive();
    _checkPosition(minMm);
    _checkPosition(maxMm);
    if (maxMm <= minMm ||
        period <= Duration.zero ||
        interval <= Duration.zero) {
      throw ArgumentError(
        'Simulation requires max > min and positive durations',
      );
    }
    if (!_status.isConnected) {
      throw StateError('Connect the mock before starting simulation');
    }
    stopSimulation();
    final watch = Stopwatch()..start();
    _timer = Timer.periodic(interval, (_) {
      final phase = watch.elapsedMicroseconds / period.inMicroseconds;
      _emitPosition(
        minMm + (maxMm - minMm) * (1 - math.cos(phase * 2 * math.pi)) / 2,
      );
    });
  }

  void stopSimulation() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> zeroX() async {
    _checkAlive();
    if (!_status.isConnected) throw StateError('Mock is disconnected');
    setPosition(0);
  }

  @override
  Future<void> disconnect() async {
    if (_disposed) return;
    stopSimulation();
    _heartbeat?.cancel();
    _heartbeat = null;
    _status = const Esp32Status(state: Esp32ConnectionState.disconnected);
    _statuses.add(_status);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await disconnect();
    _disposed = true;
    await Future.wait([_positions.close(), _statuses.close()]);
  }

  void _emitPosition(double xMm) {
    _position = Esp32Position(xMm: xMm, receivedAt: DateTime.now());
    _positions.add(_position!);
  }

  void _checkAlive() {
    if (_disposed) throw StateError('MockEsp32Service is disposed');
  }

  static void _checkPosition(double xMm) {
    if (!xMm.isFinite) throw ArgumentError.value(xMm, 'xMm', 'Must be finite');
  }
}
