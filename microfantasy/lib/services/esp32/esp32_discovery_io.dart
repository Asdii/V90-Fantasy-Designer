import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:nsd/nsd.dart' as nsd;

import 'esp32_device.dart';

/// Race the last address, DNS-SD and local UDP replies. Only an HTTP identity
/// response selects an address; advertisements never overwrite a saved machine.
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
  _DiscoveryRound? _round;
  bool _disposed = false;
  bool get isSupported => true;

  @override
  Future<Esp32Device?> resolve(Uri previous, {String? deviceId}) async {
    if (_disposed) throw StateError('Discovery is disposed');
    cancel();
    final round = _DiscoveryRound(this, deviceId);
    _round = round;
    final result = await round.run(previous);
    if (identical(_round, round)) _round = null;
    return result;
  }

  @override
  void cancel() => _round?.finish(null);

  @override
  Future<void> dispose() async {
    _disposed = true;
    cancel();
  }
}

class _DiscoveryRound {
  _DiscoveryRound(this.config, this.expectedId);
  final Esp32Discovery config;
  final String? expectedId;
  final _result = Completer<Esp32Device?>();
  final _probed = <String>{};
  final _clients = <HttpClient>{};
  final _nonce = Random.secure().nextInt(1 << 32).toRadixString(16);
  nsd.Discovery? _mdns;
  RawDatagramSocket? _udp;
  Timer? _deadline, _queryTimer;
  bool get done => _result.isCompleted;

  Future<Esp32Device?> run(Uri previous) {
    _deadline = Timer(config.scanDuration, () => finish(null));
    probe(previous.host, previous.port, previous.path);
    for (final host in config.fallbackHosts) {
      probe(host, 81, '/ws');
    }
    unawaited(_startUdp());
    if (config.enableMdns &&
        (Platform.isAndroid ||
            Platform.isIOS ||
            Platform.isMacOS ||
            Platform.isWindows)) {
      unawaited(_startMdns());
    }
    return _result.future;
  }

  void probe(String host, int port, String path) {
    if (done ||
        host.isEmpty ||
        port < 1 ||
        port > 65535 ||
        _probed.length >= 24 ||
        !_probed.add('$host:$port$path')) {
      return;
    }
    unawaited(_probe(host, port, path));
  }

  Future<void> _probe(String host, int port, String path) async {
    final client = HttpClient()..connectionTimeout = config.probeTimeout;
    _clients.add(client);
    try {
      var response = await _readInfo(client, host, '/api/v1/info');
      // Older firmware exposes the same marker on its V90 discovery bridge.
      if (response == null && expectedId == null && !done) {
        response = await _readInfo(client, host, '/api/v1/apps');
      }
      if (done || response == null) return;
      final (data, address) = response;
      if (data['service'] != 'microfantasy-machine' ||
          data['api_version'] != 1) {
        return;
      }
      final id = data['device_id'];
      if (id != null && (id is! String || id.isEmpty || id.length > 80)) return;
      if (expectedId != null && expectedId != id) return;
      final wsPort = data['ws_port'] ?? port;
      final wsPath = data['ws_path'] ?? path;
      if (wsPort is! int ||
          wsPort < 1 ||
          wsPort > 65535 ||
          wsPath is! String ||
          !wsPath.startsWith('/') ||
          wsPath.length > 128) {
        return;
      }
      finish(
        Esp32Device(
          name: 'MicroFantasy',
          host: address,
          port: wsPort,
          path: wsPath,
          id: id as String?,
        ),
      );
    } on IOException {
      // Other candidates continue while this address is unavailable.
    } on FormatException {
      // An unrelated HTTP service or malformed reply is not a machine.
    } on TimeoutException {
      // The next round obtains fresh DNS-SD/UDP replies.
    } finally {
      client.close(force: true);
      _clients.remove(client);
    }
  }

  Future<(Map<String, dynamic>, String)?> _readInfo(
    HttpClient client,
    String host,
    String path,
  ) async {
    return (() async {
      final request = await client.getUrl(
        Uri(scheme: 'http', host: host, port: config.httpPort, path: path),
      );
      request.followRedirects = false;
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final address = response.connectionInfo?.remoteAddress.address;
      if (address == null) return null;
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > 4096) {
          throw const FormatException('Identity reply too large');
        }
      }
      final data = jsonDecode(utf8.decode(bytes));
      return data is Map<String, dynamic> ? (data, address) : null;
    })().timeout(config.probeTimeout);
  }

  Future<void> _startMdns() async {
    try {
      final discovery = await nsd.startDiscovery(
        '_fantasy-machine._tcp',
        ipLookupType: nsd.IpLookupType.v4,
      );
      if (done) {
        await nsd.stopDiscovery(discovery);
        return;
      }
      _mdns = discovery;
      discovery.addListener(_readMdns);
      _readMdns();
    } catch (_) {
      // Native discovery can be unavailable; HTTP/UDP still have a deadline.
    }
  }

  void _readMdns() {
    for (final service in _mdns?.services ?? <nsd.Service>[]) {
      final port = service.port;
      if (port == null) continue;
      for (final address in service.addresses ?? <InternetAddress>[]) {
        probe(address.address, port, '/ws');
      }
      if (service.host != null) probe(service.host!, port, '/ws');
    }
  }

  Future<void> _startUdp() async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      if (done) {
        socket.close();
        return;
      }
      _udp = socket;
      socket.broadcastEnabled = true;
      socket.listen((event) {
        if (event != RawSocketEvent.read || done) return;
        final packet = socket.receive();
        if (packet == null || packet.data.length > 1024) return;
        try {
          final data = jsonDecode(utf8.decode(packet.data));
          if (data is! Map<String, dynamic> ||
              data['type'] != 'discovery' ||
              data['service'] != 'microfantasy-machine' ||
              data['api_version'] != 1 ||
              data['nonce'] != _nonce ||
              (expectedId != null && data['device_id'] != expectedId)) {
            return;
          }
          final port = data['ws_port'];
          if (port is int) probe(packet.address.address, port, '/ws');
        } on FormatException {
          // Ignore unrelated or incomplete datagrams.
        }
      }, onError: (Object _) {});
      _sendQuery();
      _queryTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _sendQuery(),
      );
    } on IOException {
      // iOS may restrict broadcasts; Bonjour remains the primary mobile route.
    }
  }

  void _sendQuery() {
    if (done) return;
    try {
      _udp?.send(
        utf8.encode(
          jsonEncode({'type': 'discover', 'api_version': 1, 'nonce': _nonce}),
        ),
        InternetAddress(config.broadcastHost),
        config.discoveryPort,
      );
    } on IOException {
      // A Wi-Fi change can invalidate this socket. The next round binds again.
    }
  }

  void finish(Esp32Device? device) {
    if (done) return;
    _result.complete(device);
    _deadline?.cancel();
    _queryTimer?.cancel();
    _udp?.close();
    for (final client in _clients) {
      client.close(force: true);
    }
    final discovery = _mdns;
    if (discovery != null) {
      discovery.removeListener(_readMdns);
      unawaited(nsd.stopDiscovery(discovery).catchError((Object _) {}));
    }
  }
}
