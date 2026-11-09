import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/services/esp32/esp32_protocol.dart';
import 'package:microfantasy/services/esp32/websocket_esp32_service.dart';

void main() {
  test(
    'boot notice requires a boolean and a valid boot ID; legacy still works',
    () {
      final t = Esp32Telemetry.decode(
        jsonEncode({
          'type': 'status',
          'connected': true,
          'boot_id': 'abc',
          'reference_revision': 0,
          'boot_notice_pending': true,
          'capabilities': ['ack_boot'],
        }),
      );
      expect(t.supportsBootNotice, true);
      expect(t.bootNoticePending, true);
      expect(
        Esp32Telemetry.decode('{"type":"position","x_mm":2}').bootNoticePending,
        isNull,
      );
      for (final payload in [
        {'type': 'status', 'connected': true, 'boot_notice_pending': true},
        {
          'type': 'status',
          'connected': true,
          'boot_id': 'abc',
          'reference_revision': 0,
          'boot_notice_pending': 'true',
        },
        {
          'type': 'status',
          'connected': true,
          'boot_id': 'abc',
          'reference_revision': 0,
          'boot_notice_pending': null,
        },
      ]) {
        expect(
          () => Esp32Telemetry.decode(jsonEncode(payload)),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'real WebSocket ACK only addresses the current boot; does not alter X',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final ready = Completer<WebSocket>();
      final commands = <Object?>[];
      server.listen((request) async {
        final peer = await WebSocketTransformer.upgrade(request);
        peer.listen((data) => commands.add(jsonDecode(data as String)));
        ready.complete(peer);
      });
      final client = WebSocketEsp32Service();
      addTearDown(() async {
        await client.dispose();
        await server.close(force: true);
      });
      await client.connect(Uri.parse('ws://127.0.0.1:${server.port}/ws'));
      final peer = await ready.future;
      Future<void> status(String boot, bool pending) async {
        final received = client.statusStream.first;
        peer.add(
          jsonEncode({
            'type': 'position',
            'x_mm': 12.5,
            'boot_id': boot,
            'reference_revision': 0,
            'boot_notice_pending': pending,
            'capabilities': ['ack_boot'],
          }),
        );
        await received.timeout(const Duration(seconds: 2));
      }

      await status('boot-1', true);
      expect(client.currentStatus.bootNoticePending, true);
      await expectLater(client.acknowledgeBoot('wrong-boot'), throwsStateError);
      await client.acknowledgeBoot('boot-1');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(commands, [
        {'type': 'ack_boot', 'boot_id': 'boot-1'},
      ]);
      expect(
        client.currentStatus.bootNoticePending,
        true,
      ); // Wait for firmware receipt.
      await status('boot-1', false);
      expect(client.currentStatus.bootNoticePending, false);
      expect(client.currentPosition!.xMm, 12.5);
      await status('boot-2', true);
      expect(client.currentStatus.bootNoticePending, true);
      await expectLater(client.acknowledgeBoot('boot-1'), throwsStateError);
      expect(commands, hasLength(1));
    },
  );
}
