import 'dart:async';
import 'esp32_device.dart';

class Esp32Discovery {
  Esp32Discovery({
    this.serviceType = '_fantasy-machine._tcp',
    this.webSocketPath = '/ws',
  });
  final String serviceType;
  final String webSocketPath;
  final _errors = StreamController<String>.broadcast();
  bool _disposed = false;
  Stream<List<Esp32Device>> get devicesStream => const Stream.empty();
  Stream<String> get errorStream => _errors.stream;
  List<Esp32Device> get devices => const [];
  bool get isDiscovering => false;
  bool get isSupported => false;
  Future<void> start({
    Duration scanDuration = const Duration(seconds: 10),
  }) async {
    if (_disposed) throw StateError('Esp32Discovery is disposed');
    _errors.add('mDNS is unavailable in web preview; use simulation');
  }

  Future<void> stop() async {}
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _errors.close();
  }
}
