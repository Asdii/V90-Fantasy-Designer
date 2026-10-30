import 'dart:async';
import 'dart:io';
import 'package:nsd/nsd.dart' as nsd;

import 'esp32_device.dart';

class Esp32Discovery {
  Esp32Discovery({
    this.serviceType = '_fantasy-machine._tcp',
    this.webSocketPath = '/ws',
  });
  final String serviceType;
  final String webSocketPath;
  final _devices = StreamController<List<Esp32Device>>.broadcast();
  final _errors = StreamController<String>.broadcast();
  List<Esp32Device> _snapshot = const [];
  nsd.Discovery? _discovery;
  Timer? _scanTimer;
  bool _disposed = false;
  bool _starting = false;
  int _generation = 0;

  Stream<List<Esp32Device>> get devicesStream => _devices.stream;
  Stream<String> get errorStream => _errors.stream;
  List<Esp32Device> get devices => _snapshot;
  bool get isDiscovering => _starting || _discovery != null;
  bool get isSupported =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows;

  Future<void> start({
    Duration scanDuration = const Duration(seconds: 10),
  }) async {
    if (_disposed) throw StateError('Esp32Discovery is disposed');
    if (scanDuration <= Duration.zero) {
      throw ArgumentError('scanDuration must be positive');
    }
    if (isDiscovering) return;
    if (!isSupported) {
      _errors.add('mDNS discovery is unsupported on this platform');
      return;
    }
    final generation = ++_generation;
    _starting = true;
    _snapshot = const [];
    _devices.add(_snapshot);
    var expired = false;
    final pending = nsd.startDiscovery(serviceType, autoResolve: true);
    unawaited(
      pending.then<void>((result) {
        if (expired || _disposed || generation != _generation) {
          unawaited(_release(result));
        }
      }, onError: (Object _, StackTrace _) {}),
    );
    try {
      final discovery = await pending.timeout(
        scanDuration,
        onTimeout: () {
          expired = true;
          throw TimeoutException('mDNS startup timed out');
        },
      );
      if (_disposed || generation != _generation) return;
      _discovery = discovery;
      _starting = false;
      discovery.addListener(_refresh);
      _refresh();
      _scanTimer = Timer(scanDuration, () => unawaited(stop()));
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _starting = false;
        _errors.add(
          'mDNS discovery failed; check local network permissions or enter an address',
        );
      }
    }
  }

  void _refresh() {
    if (_disposed) return;
    final byEndpoint = <String, Esp32Device>{};
    for (final service in _discovery?.services ?? <nsd.Service>[]) {
      final host = service.host;
      final port = service.port;
      if (host == null ||
          host.isEmpty ||
          port == null ||
          port <= 0 ||
          port > 65535) {
        continue;
      }
      final device = Esp32Device(
        name: service.name ?? host,
        host: host,
        port: port,
        path: webSocketPath,
      );
      byEndpoint[device.endpoint.toString()] = device;
    }
    final sorted = byEndpoint.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    _snapshot = List.unmodifiable(sorted);
    _devices.add(_snapshot);
  }

  Future<void> stop() async {
    _generation++;
    _starting = false;
    _scanTimer?.cancel();
    _scanTimer = null;
    final discovery = _discovery;
    _discovery = null;
    if (discovery != null) {
      discovery.removeListener(_refresh);
      await _release(discovery);
    }
  }

  Future<void> _release(nsd.Discovery discovery) async {
    try {
      await nsd.stopDiscovery(discovery);
    } catch (_) {
      if (!_disposed) _errors.add('Unable to stop native mDNS discovery');
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await Future.wait([_devices.close(), _errors.close()]);
  }
}
