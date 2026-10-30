class Esp32Device {
  const Esp32Device({
    required this.name,
    required this.host,
    required this.port,
    this.path = '/ws',
  });
  final String name;
  final String host;
  final int port;
  final String path;
  Uri get endpoint => Uri(scheme: 'ws', host: host, port: port, path: path);
}
