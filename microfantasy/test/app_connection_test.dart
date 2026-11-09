import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/app_controller.dart';
import 'package:microfantasy/models/app_settings.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/repositories/settings_repository.dart';
import 'package:microfantasy/services/esp32/esp32_service.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service.dart';

class TestMachine implements Esp32Service {
  final statuses = StreamController<Esp32Status>.broadcast();
  final positions = StreamController<Esp32Position>.broadcast();
  @override
  Esp32Position? currentPosition;
  @override
  Esp32Status currentStatus = const Esp32Status(
    state: Esp32ConnectionState.disconnected,
  );
  @override
  Stream<Esp32Status> get statusStream => statuses.stream;
  @override
  Stream<Esp32Position> get positionStream => positions.stream;
  @override
  Future<void> connect([Uri? endpoint]) async {
    currentStatus = Esp32Status(
      state: Esp32ConnectionState.connected,
      endpoint: Uri.parse('ws://192.168.1.82:81/ws'),
      deviceId: 'board-a',
    );
    currentPosition = Esp32Position(xMm: 12, receivedAt: DateTime.now());
    statuses.add(currentStatus);
    positions.add(currentPosition!);
  }

  @override
  Future<void> disconnect() async {
    currentStatus = const Esp32Status(state: Esp32ConnectionState.disconnected);
    currentPosition = null;
    statuses.add(currentStatus);
  }

  @override
  Future<void> zeroX() async =>
      throw StateError('Test must never zero the encoder');
  @override
  Future<void> dispose() async {
    await statuses.close();
    await positions.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'confirmed address persists without a reconnect loop; resume rediscovers remembered machine',
    () async {
      final store = MemoryStore();
      await SettingsRepository(store).save(
        AppSettings(simulation: false, host: '192.168.1.84', haptics: false),
      );
      final configurations = <AppSettings>[];
      final controller = AppController(
        store: store,
        designer: LocalReceiverService(port: 0, bindAddress: '127.0.0.1'),
        hardwareFactory: (settings) {
          configurations.add(settings);
          return TestMachine();
        },
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await Future<void>.delayed(Duration.zero);
      await Future.wait([
        controller.foreground(true),
        controller.foreground(true),
      ]);
      controller.nextStep();
      controller.saveCalibrationPoint();
      await controller.flush();
      expect(controller.actualX, 12);
      expect(controller.machineAddress, '192.168.1.82');
      expect(configurations, hasLength(1));
      await Future.wait([
        controller.reconnectMachine(),
        controller.reconnectMachine(),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(configurations, hasLength(2)); // Double tap produces one lookup.
      expect(controller.actualX, 12); // Reconnection never zeroes the machine.
      final saved = await SettingsRepository(store).load();
      expect(saved.host, '192.168.1.82');
      expect(saved.machineId, 'board-a');
      await controller.foreground(false);
      expect(controller.actualX, isNull);
      await controller.foreground(true);
      await Future<void>.delayed(Duration.zero);
      expect(configurations, hasLength(3));
      expect(configurations.last.machineId, 'board-a');
      expect(controller.actualX, 12);
      expect(controller.stepIndex, 1);
      expect(controller.hasCalibrationReference, isTrue);
      // A rapid pause/resume queued in the same event turn cannot tear down
      // a healthy socket after the phone is already visible again.
      await Future.wait([
        controller.foreground(false),
        controller.foreground(true),
      ]);
      expect(configurations, hasLength(3));
      expect(controller.actualX, 12);
    },
  );
}
