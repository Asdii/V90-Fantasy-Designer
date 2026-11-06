import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/services/esp32/esp32_device.dart';
import 'package:microfantasy/services/esp32/websocket_esp32_service.dart';
import 'package:microfantasy/models/app_settings.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/repositories/settings_repository.dart';

class ChangingAddress implements Esp32EndpointResolver {
  Esp32Device? next;
  final queries = <String?>[];
  @override
  Future<Esp32Device?> resolve(Uri previous, {String? deviceId}) async {
    queries.add(deviceId);
    return next;
  }

  @override
  void cancel() {}
  @override
  Future<void> dispose() async {}
}

String status(String id) => jsonEncode({
  'type': 'status',
  'connected': true,
  'service': 'microfantasy-machine',
  'api_version': 1,
  'device_id': id,
});

void main() {
  Future<HttpServer> board(String id, double x, List<WebSocket> peers) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final peer = await WebSocketTransformer.upgrade(request);
      peers.add(peer);
      peer.listen((_) {});
      peer.add(status(id));
      peer.add(jsonEncode({'type': 'position', 'x_mm': x}));
    });
    addTearDown(() => server.close(force: true));
    return server;
  }

  test(
    'rediscovers after loss, keeps identity, adopts new endpoint and fresh position',
    () async {
      final peers = <WebSocket>[];
      final first = await board('board-a', 2.0, peers);
      final second = await board('board-a', 3.0, peers);
      final resolver = ChangingAddress()
        ..next = Esp32Device(
          name: 'a',
          host: '127.0.0.1',
          port: first.port,
          id: 'board-a',
        );
      final service = WebSocketEsp32Service(
        resolver: resolver,
        reconnectDelay: const Duration(milliseconds: 10),
      );
      addTearDown(service.dispose);
      final received = service.positionStream.first;
      await service.connect(Uri.parse('ws://127.0.0.2:81/ws'));
      expect((await received.timeout(const Duration(seconds: 2))).xMm, 2);
      expect(service.currentStatus.deviceId, 'board-a');
      resolver.next = Esp32Device(
        name: 'a',
        host: '127.0.0.1',
        port: second.port,
        id: 'board-a',
      );
      final recovered = service.positionStream.first;
      await peers.first.close();
      expect((await recovered.timeout(const Duration(seconds: 2))).xMm, 3);
      expect(service.currentStatus.endpoint?.port, second.port);
      expect(resolver.queries, [null, 'board-a']);
    },
  );

  test(
    'WebSocket identity must agree with verified discovery before exposing readings',
    () async {
      final peers = <WebSocket>[];
      final wrong = await board('board-b', 500, peers);
      final resolver = ChangingAddress()
        ..next = Esp32Device(
          name: 'a',
          host: '127.0.0.1',
          port: wrong.port,
          id: 'board-a',
        );
      final service = WebSocketEsp32Service(resolver: resolver);
      addTearDown(service.dispose);
      final positions = <Esp32Position>[];
      final subscription = service.positionStream.listen(positions.add);
      addTearDown(subscription.cancel);
      final failed = service.statusStream.firstWhere(
        (s) => s.state == Esp32ConnectionState.reconnecting,
      );
      await service.connect(Uri.parse('ws://127.0.0.1:81/ws'));
      await failed.timeout(const Duration(seconds: 2));
      expect(positions, isEmpty);
      expect(service.currentPosition, isNull);
    },
  );

  test('silent machine clears stale reading then resolves again', () async {
    final peers = <WebSocket>[];
    final server = await board('board-a', 1, peers);
    final resolver = ChangingAddress()
      ..next = Esp32Device(
        name: 'a',
        host: '127.0.0.1',
        port: server.port,
        id: 'board-a',
      );
    final service = WebSocketEsp32Service(
      resolver: resolver,
      telemetryTimeout: const Duration(milliseconds: 80),
      reconnectDelay: const Duration(milliseconds: 20),
    );
    addTearDown(service.dispose);
    final received = service.positionStream.first;
    await service.connect(Uri.parse('ws://127.0.0.1:81/ws'));
    await received;
    resolver.next = null;
    final lost = service.statusStream.firstWhere(
      (s) => s.state == Esp32ConnectionState.reconnecting,
    );
    await lost.timeout(const Duration(seconds: 2));
    expect(service.currentPosition, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(resolver.queries.length, greaterThan(1));
    await service.disconnect();
    final attempts = resolver.queries.length;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(resolver.queries.length, attempts);
  });

  test(
    'stored identity survives restart and manual replacement clears it',
    () async {
      final store = MemoryStore();
      final repository = SettingsRepository(store);
      await repository.save(
        AppSettings(
          host: '192.168.1.82',
          machineId: 'board-a',
          simulation: false,
        ),
      );
      final saved = await SettingsRepository(store).load();
      expect(saved.machineId, 'board-a');
      expect(saved.host, '192.168.1.82');
      expect(
        saved.copyWith(host: '192.168.1.83', clearMachineId: true).machineId,
        isNull,
      );
      expect(AppSettings.fromJson({'host': '192.168.1.84'}).machineId, isNull);
    },
  );
}
