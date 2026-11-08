import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/app_controller.dart';
import 'package:microfantasy/models/app_settings.dart';
import 'package:microfantasy/models/x_axis_calibration.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/repositories/settings_repository.dart';
import 'package:microfantasy/repositories/x_axis_repository.dart';
import 'package:microfantasy/services/esp32/esp32_protocol.dart';
import 'package:microfantasy/services/esp32/mock_esp32_service.dart';
import 'package:microfantasy/services/esp32/websocket_esp32_service.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

class AxisWriteFailure extends MemoryStore {
  bool failAxis = false;
  @override
  Future<void> setString(String key, String value) async {
    if (failAxis && key == 'microfantasy.x_axis.v1') {
      throw StateError('Storage unavailable');
    }
    await super.setString(key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'failed persistence never changes machine zero; duplicate captures run once',
    () async {
      final store = AxisWriteFailure();
      final c = AppController(
        store: store,
        designer: LocalReceiverService(port: 0, bindAddress: '127.0.0.1'),
      );
      addTearDown(c.dispose);
      await c.initialize();
      c.simulateX(17);
      await settle();
      store.failAxis = true;
      await c.captureXCenter();
      expect(c.xCalibration, isNull);
      expect(c.sensorX, 17);
      expect(c.xCalibrationMessage, startsWith('No se pudo confirmar'));
      store.failAxis = false;
      await Future.wait([c.captureXCenter(), c.captureXCenter()]);
      await settle();
      expect(c.xAxisReady, true);
      expect(c.sensorX, 0);
      final id = c.xCalibration!.referenceId;
      c.simulateX(-5);
      await settle();
      await c.captureXNegative();
      c.simulateX(7);
      await settle();
      store.failAxis = true;
      await c.captureXPositive();
      expect(c.xCalibration!.referenceId, id);
      expect(c.xCalibration!.negativeMm, -5);
      expect(c.xCalibration!.positiveMm, isNull);
    },
  );

  test(
    'asymmetric travel persists per device, independent of simulation',
    () async {
      final store = MemoryStore();
      final repo = XAxisRepository(store);
      final axis = AxisCalibration(
        deviceId: 'machine-a',
        referenceId: 'frame-1',
        negativeMm: -32.125,
        positiveMm: 45.375,
      );
      await repo.save(axis);
      await repo.save(
        AxisCalibration(
          deviceId: 'microfantasy-simulation',
          referenceId: 'demo',
        ),
      );
      final restored = await XAxisRepository(
        MemoryStore(store.snapshot),
      ).load();
      expect(restored.length, 2);
      expect(restored.first.travelMm, 77.5);
      expect(restored.first.inverted().negativeMm, -45.375);
      expect(restored.first.inverted().positiveMm, 32.125);
      expect(restored.last.isComplete, false);
      for (final invalid in [0.0, 1.0, double.nan, double.negativeInfinity]) {
        expect(
          () => axis.withStop(positive: false, value: invalid),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'center and stops; network loss keeps reference, reboot needs physical confirmation',
    () async {
      final store = MemoryStore();
      await SettingsRepository(
        store,
      ).save(AppSettings(simulation: false, haptics: false));
      late MockEsp32Service machine;
      final c = AppController(
        store: store,
        designer: LocalReceiverService(port: 0, bindAddress: '127.0.0.1'),
        hardwareFactory: (_) =>
            machine = MockEsp32Service(initialPositionMm: 12),
      );
      addTearDown(c.dispose);
      await c.initialize();
      machine.setPosition(12);
      await settle();
      expect(c.actualX, isNull); // New real hardware needs a physical center.
      await c.captureXCenter();
      await settle();
      c.saveCalibrationPoint();
      await c.flush();
      expect(c.xAxisReady, true);
      expect(c.actualX, 0);
      expect(c.profile.referenceX, 0);
      machine.setPosition(-32.125);
      await settle();
      await c.captureXNegative();
      machine.setPosition(45.375);
      await settle();
      await c.captureXPositive();
      expect(c.xCalibration!.travelMm, 77.5);
      final id = c.xCalibration!.referenceId;
      await machine.disconnect();
      await settle();
      expect(c.actualX, isNull);
      await machine.connect();
      machine.setPosition(19.25);
      await settle();
      expect(c.actualX, 19.25);
      expect(c.xAxisReady, true);
      await machine.simulateRestart();
      await settle();
      expect(c.machineConnected, true);
      expect(c.sensorX, 0);
      expect(c.actualX, isNull);
      expect(c.xNeedsReference, true);
      // A sample whose numeric value happens to equal a stop cannot auto-home.
      machine.setPosition(-32.125);
      await settle();
      expect(c.actualX, isNull);
      await c.referenceXAtStop(positive: false);
      await settle();
      expect(c.actualX, -32.125);
      expect(machine.currentStatus.referenceId, id);
      machine.setPosition(0);
      await settle();
      expect(c.actualX, 0);
      await machine.simulateRestart();
      await settle();
      await c.referenceXAtStop(positive: true);
      await settle();
      expect(c.actualX, 45.375);
      expect((await XAxisRepository(store).load()).single.referenceId, id);
      await machine.simulateRestart();
      await settle();
      await c.resetXCalibration();
      expect(c.xCalibration, isNull);
      expect(c.machineConnected, true);
      expect(c.actualX, isNull); // Deleting calibration cannot bless boot zero.
    },
  );

  test(
    'saved travel survives app restart without silently zeroing a new boot',
    () async {
      final store = MemoryStore();
      await SettingsRepository(
        store,
      ).save(AppSettings(simulation: false, haptics: false));
      await XAxisRepository(store).save(
        AxisCalibration(
          deviceId: 'microfantasy-simulation',
          referenceId: 'saved',
          negativeMm: -10,
          positiveMm: 15,
        ),
      );
      late MockEsp32Service machine;
      final c = AppController(
        store: store,
        designer: LocalReceiverService(port: 0, bindAddress: '127.0.0.1'),
        hardwareFactory: (_) => machine = MockEsp32Service(),
      );
      addTearDown(c.dispose);
      await c.initialize();
      await settle();
      expect(c.xCalibration!.travelMm, 25);
      expect(c.actualX, isNull);
      expect(machine.currentStatus.referenceId, isNull);
      await c.captureXNegative();
      expect(c.xCalibrationMessage, contains('No se pudo confirmar'));
      expect(c.xCalibration!.negativeMm, -10);
      await c.referenceXAtStop(positive: false);
      await settle();
      expect(c.actualX, -10);
      await c.updateSettings(c.settings.copyWith(invertX: true));
      expect(c.actualX, 10);
      expect(c.xCalibration!.negativeMm, -15);
      expect(c.xCalibration!.positiveMm, 10);
      await c.referenceXAtStop(positive: false);
      await settle();
      expect(c.actualX, -15);
      expect(machine.currentPosition!.xMm, 15);
    },
  );

  test('metadata and reference ACK require finite coordinates and a boot', () {
    for (final frame in [
      {'type': 'position', 'x_mm': 0, 'boot_id': 'b'},
      {'type': 'position', 'x_mm': 0, 'reference_id': 'r'},
      {'type': 'position', 'x_mm': 0, 'boot_id': 'b', 'reference_revision': -1},
      {
        'type': 'reference_ack',
        'request_id': 'q',
        'accepted': true,
        'boot_id': 'b',
        'reference_revision': 1,
        'x_mm': 0,
      },
    ]) {
      expect(
        () => Esp32Telemetry.decode(jsonEncode(frame)),
        throwsFormatException,
      );
    }
    expect(() => validateXReference('b', 'r', double.nan), throwsArgumentError);
    expect(() => validateXReference('b', 'r', 10001), throwsArgumentError);
  });

  test(
    'real WS command waits for its ACK, rejects stale samples and never resends',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final peerReady = Completer<WebSocket>();
      final commands = StreamController<Map<String, dynamic>>();
      server.listen((r) async {
        final ws = await WebSocketTransformer.upgrade(r);
        ws.listen(
          (data) =>
              commands.add(jsonDecode(data as String) as Map<String, dynamic>),
        );
        peerReady.complete(ws);
      });
      final s = WebSocketEsp32Service();
      addTearDown(() async {
        await s.dispose();
        await commands.close();
        await server.close(force: true);
      });
      await s.connect(Uri.parse('ws://127.0.0.1:${server.port}/ws'));
      final peer = await peerReady.future;
      final stream = StreamIterator(commands.stream);
      addTearDown(stream.cancel);
      final ready = s.positionStream.first;
      peer.add(
        jsonEncode({
          'type': 'status',
          'connected': true,
          'boot_id': 'boot-1',
          'reference_id': null,
          'reference_revision': 0,
          'capabilities': ['set_x_reference'],
        }),
      );
      peer.add(
        jsonEncode({
          'type': 'position',
          'x_mm': 8,
          'boot_id': 'boot-1',
          'reference_id': null,
          'reference_revision': 0,
        }),
      );
      await ready;
      bool finished = false;
      final ack = s.setXReference(
        bootId: 'boot-1',
        referenceId: 'physical',
        xMm: -32.125,
      )..then((_) => finished = true);
      expect(await stream.moveNext(), true);
      final request = stream.current;
      expect(request['x_mm'], -32.125);
      expect(request['type'], 'set_x_reference');
      await settle();
      expect(finished, false);
      await expectLater(
        s.setXReference(bootId: 'boot-1', referenceId: 'physical', xMm: 1),
        throwsStateError,
      );
      peer.add(
        jsonEncode({
          'type': 'reference_ack',
          'request_id': request['request_id'],
          'accepted': true,
          'boot_id': 'boot-1',
          'reference_id': 'physical',
          'reference_revision': 1,
          'x_mm': -32.125,
        }),
      );
      expect((await ack).xMm, -32.125);
      peer.add(
        jsonEncode({
          'type': 'position',
          'x_mm': 8,
          'boot_id': 'boot-1',
          'reference_id': null,
          'reference_revision': 0,
        }),
      );
      await settle();
      expect(s.currentPosition!.xMm, -32.125);
      final pending = s.setXReference(
        bootId: 'boot-1',
        referenceId: 'physical',
        xMm: 45,
      );
      final rejected = expectLater(pending, throwsStateError);
      expect(await stream.moveNext(), true);
      await s.disconnect();
      await rejected;
      expect(s.currentPosition, isNull);
    },
  );
}
