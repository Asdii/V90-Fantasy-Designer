import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/app_controller.dart';
import 'package:microfantasy/models/models.dart';
import 'package:microfantasy/models/job_progress.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('step navigation is bounded in both directions', () {
    final progress = JobProgress(CuttingJob.demo());
    progress.previous();
    expect(progress.index, 0);
    for (var n = 0; n < 20; n++) {
      progress.next();
    }
    expect(progress.index, 5);
    progress.previous();
    expect(progress.index, 4);
  });

  test(
    'session, calibration and pending job survive a fresh controller',
    () async {
      final store = MemoryStore();
      final first = AppController(
        store: store,
        designer: LocalReceiverService(),
      );
      await first.initialize();
      await first.updateSettings(first.settings.copyWith(haptics: false));
      first.simulateX(12);
      await Future<void>.delayed(Duration.zero);
      first.saveCalibrationPoint();
      for (var n = 0; n < 6; n++) {
        first.nextAngle();
      }
      first.simulateX(15.2);
      await Future<void>.delayed(Duration.zero);
      first.saveCalibrationPoint();
      expect(first.getXOffsetForAngle(180), closeTo(3.2, 1e-9));
      expect(
        first.getCorrectedTargetX(
          CuttingStep(index: 1, angleR: 180, x: 12, depth: .3),
        ),
        closeTo(15.2, 1e-9),
      );
      first.nextStep();
      first.nextStep();
      final incoming = CuttingJob(
        jobId: 'new',
        name: 'Nuevo patrón',
        steps: [CuttingStep(index: 1, angleR: 180, x: 12, depth: .3)],
      );
      await first.receiveJob(incoming);
      expect(first.job!.id, 'demo-hexagon');
      await first.flush();
      first.dispose();
      final second = AppController(
        store: store,
        designer: LocalReceiverService(),
      );
      await second.initialize();
      expect(second.stepIndex, 2);
      expect(second.calibrationAngle, 180);
      expect(second.profile.points.length, 2);
      expect(second.pendingJob!.id, 'new');
      second.acceptPending();
      expect(second.correctedTarget, closeTo(15.2, 1e-9));
      await second.flush();
      second.dispose();
    },
  );

  test(
    'inversion changes raw readings and calibration, never nominal X',
    () async {
      final c = AppController(
        store: MemoryStore(),
        designer: LocalReceiverService(),
      );
      await c.initialize();
      await c.updateSettings(c.settings.copyWith(haptics: false));
      c.simulateX(12);
      await Future<void>.delayed(Duration.zero);
      c.saveCalibrationPoint();
      c.nextAngle();
      c.simulateX(13);
      await Future<void>.delayed(Duration.zero);
      c.saveCalibrationPoint();
      await c.updateSettings(c.settings.copyWith(invertX: true));
      expect(c.actualX, -13);
      expect(c.getXOffsetForAngle(30), -1);
      expect(
        c.getCorrectedTargetX(
          CuttingStep(index: 0, angleR: 30, x: 12, depth: 0),
        ),
        11,
      );
      await c.flush();
      c.dispose();
    },
  );
}
