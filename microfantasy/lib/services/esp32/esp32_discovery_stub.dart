import 'esp32_device.dart';

class Esp32Discovery implements Esp32EndpointResolver {
  Esp32Discovery({
    this.scanDuration = const Duration(seconds: 3),
    this.probeTimeout = const Duration(milliseconds: 700),
    this.httpPort = 80,
    this.discoveryPort = 42190,
    this.enableMdns = true,
    this.broadcastHost = '255.255.255.255',
    this.fallbackHosts = const ['fantasy-machine.local', '192.168.4.1'],
  });

  final Duration scanDuration, probeTimeout;
  final int httpPort, discoveryPort;
  final bool enableMdns;
  final String broadcastHost;
  final List<String> fallbackHosts;
  bool get isSupported => false;
  @override
  Future<Esp32Device?> resolve(Uri previous, {String? deviceId}) async => null;
  @override
  void cancel() {}
  @override
  Future<void> dispose() async {}
}
