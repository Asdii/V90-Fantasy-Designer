class Esp32Device {
  const Esp32Device({
    required this.name,
    required this.host,
    required this.port,
    this.path = '/ws',
    this.id,
  });
  final String name;
  final String host;
  final int port;
  final String path;
  final String? id;
  Uri get endpoint => Uri(scheme: 'ws', host: host, port: port, path: path);
}

/// Discover the current address and verify the remembered machine identity.
abstract interface class Esp32EndpointResolver {
  Future<Esp32Device?> resolve(Uri previous, {String? deviceId});
  void cancel();
  Future<void> dispose();
}
