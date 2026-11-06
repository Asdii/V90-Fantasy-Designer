import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/services/esp32/esp32_discovery.dart';

Map<String, Object?> identity(String id) => {
  'service': 'microfantasy-machine', 'api_version': 1,
  'device_id': id, 'ws_port': 81, 'ws_path': '/ws',
  // An AP reply may contain the home IP. Use the reachable peer address.
  'ip': '192.168.1.84',
};

void main() {
  Future<HttpServer> serve(Object body, {int status = 200}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = status;
      request.response.write(jsonEncode(body));
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    return server;
  }

  Esp32Discovery discovery(int port, {int udpPort = 42190}) {
    final result = Esp32Discovery(
      enableMdns: false,
      httpPort: port,
      discoveryPort: udpPort,
      broadcastHost: '127.0.0.1',
      fallbackHosts: const [],
      scanDuration: const Duration(milliseconds: 300),
      probeTimeout: const Duration(milliseconds: 80),
    );
    addTearDown(result.dispose);
    return result;
  }

  test(
    'verifies identity and uses actual responding IP instead of advertised IP',
    () async {
      final server = await serve(identity('board-a'));
      final device = await discovery(
        server.port,
      ).resolve(Uri.parse('ws://127.0.0.1:81/ws'), deviceId: 'board-a');
      expect(device?.host, '127.0.0.1');
      expect(device?.id, 'board-a');
      expect(device?.endpoint.toString(), 'ws://127.0.0.1:81/ws');
    },
  );

  test(
    'rejects stale IP reassigned to another machine or an unrelated server',
    () async {
      for (final body in [
        identity('board-b'),
        {'api_version': 1},
        'a router page',
      ]) {
        final server = await serve(body);
        expect(
          await discovery(
            server.port,
          ).resolve(Uri.parse('ws://127.0.0.1:81/ws'), deviceId: 'board-a'),
          isNull,
        );
      }
    },
  );

  test('UDP locates a changed address while cached address fails', () async {
    final server = await serve(identity('board-a'));
    final udp = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(udp.close);
    udp.listen((event) {
      if (event != RawSocketEvent.read) return;
      final packet = udp.receive();
      if (packet == null) return;
      final query =
          jsonDecode(utf8.decode(packet.data)) as Map<String, dynamic>;
      final response = {
        ...identity('board-a'),
        'type': 'discovery',
        'nonce': query['nonce'],
      };
      udp.send(utf8.encode(jsonEncode(response)), packet.address, packet.port);
    });
    final device = await discovery(
      server.port,
      udpPort: udp.port,
    ).resolve(Uri.parse('ws://127.0.0.2:81/ws'), deviceId: 'board-a');
    expect(device?.host, '127.0.0.1');
    expect(device?.id, 'board-a');
  });

  test('unrelated UDP replies cannot select an address', () async {
    final server = await serve(identity('board-a'));
    final udp = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(udp.close);
    udp.listen((event) {
      if (event != RawSocketEvent.read) return;
      final packet = udp.receive();
      if (packet == null) return;
      udp.send(
        utf8.encode(
          jsonEncode({
            ...identity('board-a'),
            'type': 'discovery',
            'nonce': 'wrong',
          }),
        ),
        packet.address,
        packet.port,
      );
    });
    expect(
      await discovery(
        server.port,
        udpPort: udp.port,
      ).resolve(Uri.parse('ws://127.0.0.2:81/ws')),
      isNull,
    );
  });

  test(
    'legacy firmware remains discoverable until an identity is remembered',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.statusCode = request.uri.path == '/api/v1/apps'
            ? 200
            : 404;
        request.response.write(
          jsonEncode({
            'service': 'microfantasy-machine',
            'api_version': 1,
            'apps': [],
          }),
        );
        await request.response.close();
      });
      final resolver = discovery(server.port);
      final uri = Uri.parse('ws://127.0.0.1:81/ws');
      expect((await resolver.resolve(uri))?.endpoint, uri);
      expect(await resolver.resolve(uri, deviceId: 'board-a'), isNull);
    },
  );

  test(
    'canceling discovery releases wait immediately and ignores late response',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requestReady = Completer<HttpRequest>();
      server.listen(requestReady.complete);
      final resolver = discovery(server.port);
      final pending = resolver.resolve(Uri.parse('ws://127.0.0.1:81/ws'));
      await requestReady.future;
      resolver.cancel();
      expect(await pending, isNull);
      final request = await requestReady.future;
      request.response.write(jsonEncode(identity('board-a')));
      await request.response.close();
    },
  );
}
