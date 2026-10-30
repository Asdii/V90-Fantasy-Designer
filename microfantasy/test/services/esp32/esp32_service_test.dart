import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/services/esp32/esp32_protocol.dart';
import 'package:microfantasy/services/esp32/mock_esp32_service.dart';
import 'package:microfantasy/services/esp32/websocket_esp32_service.dart';

void main() {
  test('manual mock position remains fresh until disconnect', () async {
    final mock = MockEsp32Service(
      telemetryInterval: const Duration(milliseconds: 10),
    );
    addTearDown(mock.dispose);
    await mock.connect();
    mock.setPosition(8.5);
    final initialTime = mock.currentPosition!.receivedAt;
    final heartbeat = await mock.positionStream.first;
    expect(heartbeat.xMm, 8.5);
    expect(heartbeat.receivedAt.isAfter(initialTime), true);
    await mock.disconnect();
    final lastTime = mock.currentPosition!.receivedAt;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(mock.currentPosition!.receivedAt, lastTime);
  });

  group('telemetry protocol', () {
    test('accepts exact boolean connected status without a status string', () {
      for (final connected in [true, false]) {
        final telemetry = Esp32Telemetry.decode(
          jsonEncode({'type': 'status', 'connected': connected}),
        );
        expect(telemetry.connected, connected);
        expect(telemetry.status, isNull);
        expect(telemetry.xMm, isNull);
      }
    });

    test('decodes numeric millimetres and bounded status from UTF-8', () {
      final value = Esp32Telemetry.decode(
        utf8.encode('{"type":"position","x_mm":-12.5,"status":"ready"}'),
      );
      expect(value.xMm, -12.5);
      expect(value.status, 'ready');
      expect(
        Esp32Telemetry.decode('{"type":"status","status":"idle"}').xMm,
        isNull,
      );
    });

    test('rejects malformed, non-finite, command and missing telemetry', () {
      for (final message in [
        '[]',
        '{}',
        'not json',
        '{"x_mm":"2"}',
        '{"x_mm":1e400}',
        '{"type":"move","x_mm":3}',
        '{"type":"position","status":"ready"}',
        '{"status":null}',
        '{"type":"status","connected":null}',
        '{"type":"status","connected":"false"}',
        '{"type":"status","connected":0}',
      ]) {
        expect(
          () => Esp32Telemetry.decode(message),
          throwsFormatException,
          reason: message,
        );
      }
    });

    test('checks byte size including multibyte strings', () {
      expect(
        () => Esp32Telemetry.decode('{"status":"éééé"}', maxBytes: 18),
        throwsFormatException,
      );
      expect(
        () => Esp32Telemetry.decode(List.filled(30, 32), maxBytes: 20),
        throwsFormatException,
      );
    });
  });

  test(
    'manual slider takes control from timer and disconnect stops updates',
    () async {
      final mock = MockEsp32Service();
      addTearDown(mock.dispose);
      await mock.connect();
      mock.startSimulation(
        interval: const Duration(milliseconds: 5),
        period: const Duration(milliseconds: 30),
      );
      final update = await mock.positionStream.first.timeout(
        const Duration(seconds: 1),
      );
      expect(update.xMm, inInclusiveRange(0, 20));
      mock.setPosition(7);
      expect(mock.isSimulating, false);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(mock.currentPosition!.xMm, 7);
      expect(() => mock.setPosition(double.nan), throwsArgumentError);
      await mock.zeroX();
      expect(mock.currentPosition!.xMm, 0);
      await mock.disconnect();
      expect(mock.currentStatus.state, Esp32ConnectionState.disconnected);
    },
  );

  test(
    'native WebSocket receives telemetry and only explicit opt-in sends zero_x',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final peerReady = Completer<WebSocket>();
      final received = <dynamic>[];
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen(received.add);
        peerReady.complete(socket);
      });
      final service = WebSocketEsp32Service(allowZeroX: true);
      addTearDown(() async {
        await service.dispose();
        await server.close(force: true);
      });
      await service.connect(Uri.parse('ws://127.0.0.1:${server.port}/ws'));
      final peer = await peerReady.future;
      final position = service.positionStream.first;
      peer.add('{"type":"position","x_mm":3.25}');
      expect((await position.timeout(const Duration(seconds: 2))).xMm, 3.25);
      expect(received, isEmpty);
      await service.zeroX();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(received.map((dynamic item) => jsonDecode(item as String)), [
        {'type': 'zero_x'},
      ]);
    },
  );

  test(
    'false status invalidates without a position and only true or position recovers',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final peerReady = Completer<WebSocket>();
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((_) {});
        peerReady.complete(socket);
      });
      final service = WebSocketEsp32Service(allowZeroX: true);
      final positions = <Esp32Position>[];
      final subscription = service.positionStream.listen(positions.add);
      addTearDown(() async {
        await subscription.cancel();
        await service.dispose();
        await server.close(force: true);
      });
      await service.connect(Uri.parse('ws://127.0.0.1:${server.port}/ws'));
      expect(service.currentStatus.isConnected, false);
      final peer = await peerReady.future;
      Future<Esp32Status> deliver(String frame) async {
        final next = service.statusStream.first;
        peer.add(frame);
        final status = await next.timeout(const Duration(seconds: 2));
        await Future<void>.delayed(Duration.zero);
        return status;
      }

      await deliver('{"type":"position","x_mm":12.5}');
      expect(service.currentPosition!.xMm, 12.5);
      expect(service.currentStatus.isConnected, true);
      expect(positions.map((position) => position.xMm), [12.5]);

      final offline = await deliver('{"type":"status","connected":false}');
      expect(offline.state, Esp32ConnectionState.disconnected);
      expect(service.currentPosition, isNull);
      await expectLater(service.zeroX(), throwsStateError);
      for (final frame in [
        'not json',
        '{"type":"status","status":"ready"}',
        '{"type":"status","connected":false,"x_mm":0}',
      ]) {
        expect((await deliver(frame)).isConnected, false);
        expect(service.currentPosition, isNull);
        expect(positions.map((position) => position.xMm), [12.5]);
      }

      expect(
        (await deliver('{"type":"status","connected":true}')).isConnected,
        true,
      );
      expect(service.currentPosition, isNull); // No cached reading is restored.
      expect(positions.map((position) => position.xMm), [12.5]);

      await deliver('{"type":"status","connected":false}');
      expect((await deliver('{"type":"position","x_mm":7}')).isConnected, true);
      expect(service.currentPosition!.xMm, 7);
      expect(positions.map((position) => position.xMm), [12.5, 7]);
      await service.disconnect();
      expect(service.currentPosition, isNull);
    },
  );

  test(
    'reconnects after stale telemetry and stops retries on disconnect',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      final second = Completer<void>();
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.listen((_) {});
        if (sockets.length == 2) second.complete();
      });
      final service = WebSocketEsp32Service(
        telemetryTimeout: const Duration(milliseconds: 80),
        reconnectDelay: const Duration(milliseconds: 20),
        maxReconnectDelay: const Duration(milliseconds: 40),
      );
      addTearDown(() async {
        await service.dispose();
        for (final socket in sockets) {
          await socket.close();
        }
        await server.close(force: true);
      });
      await service.connect(Uri.parse('ws://127.0.0.1:${server.port}/ws'));
      await expectLater(service.zeroX(), throwsUnsupportedError);
      await second.future.timeout(const Duration(seconds: 3));
      await service.disconnect();
      final count = sockets.length;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(sockets.length, count);
      expect(service.currentStatus.state, Esp32ConnectionState.disconnected);
    },
  );

  test('disconnect during handshake prevents a late live connection', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requestReady = Completer<HttpRequest>();
    server.listen(requestReady.complete);
    final service = WebSocketEsp32Service();
    addTearDown(() async {
      await service.dispose();
      await server.close(force: true);
    });
    final connecting = service.connect(
      Uri.parse('ws://127.0.0.1:${server.port}/ws'),
    );
    final request = await requestReady.future;
    await service.disconnect();
    final peer = await WebSocketTransformer.upgrade(request);
    final closed = peer.drain<void>();
    await connecting;
    await closed.timeout(const Duration(seconds: 3));
    expect(service.currentStatus.state, Esp32ConnectionState.disconnected);
  });
}
