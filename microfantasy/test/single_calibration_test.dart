import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/app_controller.dart';
import 'package:microfantasy/models/models.dart';
import 'package:microfantasy/repositories/calibration_repository.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/repositories/settings_repository.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service.dart';
import 'package:microfantasy/services/file_transfer.dart';

AppController controller(MemoryStore store, {FileTransfer? files}) =>
    AppController(
      store: store,
      files: files,
      designer: LocalReceiverService(port: 0, bindAddress: '127.0.0.1'),
    );

Future<void> setX(AppController c, double x) async {
  c.simulateX(x);
  await Future<void>.delayed(Duration.zero);
}

CalibrationProfile sample(String id, double offset) => CalibrationProfile(
  id: id,
  name: id,
  referenceX: 12,
  points: [
    CalibrationPoint(angleR: 0, x: 12),
    CalibrationPoint(angleR: 180, x: 12 + offset),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'zero is mandatory; points persist and compensate without explicit save',
    () async {
      final store = MemoryStore();
      final c = controller(store);
      await c.initialize();
      c.nextAngle();
      c.previousAngle();
      expect(c.calibrationAngle, 0);
      await setX(c, 12);
      final notices = c.noticeId;
      c.saveCalibrationPoint();
      await c.flush();
      expect(c.noticeId, notices); // No snackbar over the navigation buttons.
      expect(c.calibrationSavedId, 1);
      expect(c.lastSavedCalibrationAngle, 0);
      for (var i = 0; i < 6; i++) {
        c.nextAngle();
      }
      await setX(c, 15.2);
      c.saveCalibrationPoint();
      expect(c.getXOffsetForAngle(180), closeTo(3.2, 1e-10));
      await c.flush();
      expect(
        (await CalibrationRepository(store).load()).single.points.length,
        2,
      );
      c.dispose();
      final restarted = controller(store);
      await restarted.initialize();
      expect(restarted.calibrationAngle, 0);
      expect(restarted.getXOffsetForAngle(180), closeTo(3.2, 1e-10));
      restarted
          .removeCalibrationPoint(); // Removing the reference invalidates all samples.
      await restarted.flush();
      expect(restarted.compensationActive, false);
      expect(restarted.profile.points, isEmpty);
      restarted.dispose();
    },
  );

  test(
    'failed persistence never announces a successfully saved point',
    () async {
      final store = _FailingStore();
      final c = controller(store);
      await c.initialize();
      await setX(c, 12);
      store.failCalibration = true;
      c.saveCalibrationPoint();
      await c.flush();
      expect(c.calibrationSavedId, 0);
      expect(c.notice, contains('No se pudo guardar'));
      c.dispose();
    },
  );

  test(
    'migration retains the active calibration and archives legacy profiles',
    () async {
      final store = MemoryStore();
      final repo = CalibrationRepository(store);
      await repo.save(sample('old', 1));
      await repo.save(sample('selected', 3.2));
      await SettingsRepository(
        store,
      ).save(AppSettings(activeProfileId: 'selected'));
      final c = controller(store);
      await c.initialize();
      expect(c.profiles.length, 1);
      expect(c.profile.id, 'selected');
      expect(c.getXOffsetForAngle(180), closeTo(3.2, 1e-10));
      expect((await repo.load()).length, 1);
      final backup = jsonDecode(
        (await store.getString(CalibrationRepository.legacyBackupKey))!,
      );
      expect(backup['items'].length, 2);
      c.resetSettings();
      await c.flush();
      c.dispose();
      final restarted = controller(store);
      await restarted.initialize();
      expect(restarted.profile.id, 'selected');
      restarted.dispose();
    },
  );

  test(
    'receiver starts automatically and restarts when returning to foreground',
    () async {
      final c = controller(MemoryStore());
      await c.initialize();
      expect(c.receiving, true);
      await c.foreground(false);
      expect(c.receiving, false);
      await c.foreground(true);
      expect(c.receiving, true);
      await Future.wait([
        c.foreground(false),
        c.foreground(true),
        c.ensureReceiver(),
      ]);
      expect(c.receiving, true);
      c.dispose();
    },
  );

  test(
    'import replaces the single calibration rather than adding a profile',
    () async {
      final store = MemoryStore();
      final files = _Files(
        jsonEncode({
          'version': 2,
          'calibration': sample('imported', 2).toJson(),
        }),
      );
      final c = controller(store, files: files);
      await c.initialize();
      await c.importCalibrations();
      await c.flush();
      expect(c.profiles.length, 1);
      expect(c.profile.id, 'principal');
      expect(c.getXOffsetForAngle(180), 2);
      await c.exportCalibrations();
      expect(jsonDecode(files.saved!)['calibration']['id'], 'principal');
      expect(jsonDecode(files.saved!)['version'], 2);
      c.dispose();
    },
  );
}

class _Files extends FileTransfer {
  _Files(this.source);
  final String source;
  String? saved;
  @override
  Future<String?> readJson() async => source;
  @override
  Future<bool> saveJson(String name, String text) async {
    saved = text;
    return true;
  }
}

class _FailingStore extends MemoryStore {
  bool failCalibration = false;
  @override
  Future<void> setString(String key, String value) async {
    if (failCalibration && key == CalibrationRepository.storageKey) {
      throw StateError('Storage full');
    }
    await super.setString(key, value);
  }
}
