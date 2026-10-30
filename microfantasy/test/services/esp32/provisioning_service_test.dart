import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/services/esp32/provisioning_service.dart';
import 'package:microfantasy/services/esp32/esp32_protocol.dart';

void main() {
  test('Wi-Fi payload preserves spaces and validates byte limits', () {
    expect(jsonDecode(setupPayload('Mi red ', ' pass word ')), {
      'ssid': 'Mi red ',
      'password': ' pass word ',
    });
    expect(jsonDecode(setupPayload('Open', ''))['password'], '');
    for (final pair in [
      ('', '12345678'),
      ('a' * 33, ''),
      ('é' * 17, ''),
      ('WiFi', 'short'),
      ('WiFi', 'x' * 64),
      ('bad\u0000name', ''),
    ]) {
      expect(() => setupPayload(pair.$1, pair.$2), throwsFormatException);
    }
  });

  test(
    'App reads firmware status and negative position without assuming motion',
    () {
      expect(
        Esp32Telemetry.decode(
          '{"type":"status","connected":true,"status":"incremental_ready","sensor":"unverified","wifi":"ok"}',
        ).connected,
        true,
      );
      expect(
        Esp32Telemetry.decode(
          '{"type":"position","x_mm":-1.953125,"timestamp":42}',
        ).xMm,
        -1.953125,
      );
    },
  );

  test(
    'HTTP provisioning sends credentials and confirms device connection',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      Map<String, dynamic>? received;
      server.listen((request) async {
        expect(request.uri.path, '/api/v1/setup');
        request.response.headers.contentType = ContentType.json;
        if (request.method == 'POST') {
          received =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          request.response.statusCode = 202;
          request.response.write('{"accepted":true}');
        } else {
          request.response.write(
            jsonEncode({
              'device': 'MicroFantasy',
              'schemaVersion': 1,
              'connected': received != null,
              'connecting': false,
              'ip': received == null ? '0.0.0.0' : '192.168.1.50',
              'error': '',
            }),
          );
        }
        await request.response.close();
      });
      final service = HttpMachineProvisioningService(
        endpoint: Uri.parse('http://127.0.0.1:${server.port}/api/v1/setup'),
      );
      expect((await service.status()).connected, false);
      await service.configure('Home', 'test-pass');
      expect(received, {'ssid': 'Home', 'password': 'test-pass'});
      final status = await service.status();
      expect(status.connected, true);
      expect(status.ip, '192.168.1.50');
    },
  );

  test('Redirects cannot receive Wi-Fi credentials', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var requests = 0;
    server.listen((request) async {
      requests++;
      await request.drain<void>();
      request.response.statusCode = 307;
      request.response.headers.set('location', '/other');
      await request.response.close();
    });
    final service = HttpMachineProvisioningService(
      endpoint: Uri.parse('http://127.0.0.1:${server.port}/api/v1/setup'),
    );
    await expectLater(
      service.configure('Home', 'test-pass'),
      throwsA(isA<HttpException>()),
    );
    expect(requests, 1);
  });

  test('Malformed status is rejected', () {
    expect(
      () => MachineSetupStatus.fromJson({'connected': true}),
      throwsFormatException,
    );
    expect(
      () => MachineSetupStatus.fromJson({
        'device': 'MicroFantasy',
        'schemaVersion': 1,
        'connected': true,
        'connecting': false,
        'ip': '0.0.0.0',
        'error': '',
      }),
      throwsFormatException,
    );
  });
}
