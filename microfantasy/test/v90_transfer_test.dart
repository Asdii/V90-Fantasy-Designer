import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/app_controller.dart';
import 'package:microfantasy/main.dart';
import 'package:microfantasy/models/cutting_job.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service.dart';
import 'package:microfantasy/widgets/v90_cut_helper.dart';

Map<String, Object?> fixture() => Map<String, Object?>.from(
  jsonDecode(File('examples/v90-cut-helper.json').readAsStringSync()),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'exact V90 fixture round-trips all viewer geometry and signed positions',
    () {
      final json = fixture(), job = CuttingJob.fromJson(fixture());
      expect(job.toJson(), json);
      expect(job.steps.map((s) => s.x), [12.5, 11.5, 13]);
      expect(job.cutHelper!.referenceFacetId, 7);
      expect(job.cutHelper!.boundary.first.u, -2);
      expect(job.cutHelper!.steps.last.segment.start.u, 1);
    },
  );
  test(
    'rejects incompatible or inconsistent helper data without falling back to a fake preview',
    () {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (j) => j['cutHelper']['version'] = 99,
        (j) => j['cutHelper']['initialView']['stepIndex'] = 100,
        (j) => j['steps'][0]['x'] = -12.5,
        (j) => j['steps'][0]['angleR'] = 90,
        (j) => j['cutHelper']['steps'][0]['signedDistanceMm'] = -.5,
      ]) {
        final json = jsonDecode(jsonEncode(fixture())) as Map<String, dynamic>;
        mutate(json);
        expect(() => CuttingJob.fromJson(json), throwsFormatException);
      }
    },
  );
  test(
    'opening a transferred helper restores its initial view and persists later progress',
    () async {
      final store = MemoryStore();
      final c = AppController(
        store: store,
        designer: LocalReceiverService(port: 0, bindAddress: '127.0.0.1'),
      );
      await c.initialize();
      await c.receiveJob(CuttingJob.fromJson(fixture()));
      c.acceptPending();
      expect(c.stepIndex, 2);
      expect(c.helperDirection, 'vertical');
      expect(c.correctedTarget, 13);
      c.previousStep();
      c.setHelperDirection('horizontal');
      c.setHelperZero(true);
      await c.flush();
      c.dispose();
      final restored = AppController(
        store: store,
        designer: LocalReceiverService(port: 0, bindAddress: '127.0.0.1'),
      );
      await restored.initialize();
      expect(restored.stepIndex, 1);
      expect(restored.helperZeroView, true);
      expect(restored.helperDirection, 'horizontal');
      expect(restored.job!.cutHelper!.toJson(), fixture()['cutHelper']);
      restored.nextStep();
      expect(restored.helperZeroView, false);
      await restored.flush();
      restored.dispose();
    },
  );
  testWidgets(
    'mobile displays V90 scene and has working direction, zero and step controls',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late AppController c;
      await tester.runAsync(() async {
        c = AppController(
          store: MemoryStore(),
          designer: LocalReceiverService(port: 0, bindAddress: '127.0.0.1'),
        );
        await c.initialize();
        await c.receiveJob(CuttingJob.fromJson(fixture()));
        c.acceptPending();
        await c.flush();
      });
      await tester.pumpWidget(MicroFantasyApp(controller: c));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(V90CutHelper), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Abrir Cut Helper'));
      await tester.tap(find.byTooltip('Abrir Cut Helper'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Operación 2 · Faceta de referencia 7'), findsOneWidget);
      await tester.tap(find.text('Horizontal →'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.helperDirection, 'horizontal');
      expect(c.stepIndex, 2);
      await tester.tap(find.text('Volver a 0°'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.helperZeroView, true);
      await tester.tap(find.text('← Anterior'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.stepIndex, 1);
      expect(c.helperZeroView, false);
      expect(tester.takeException(), isNull);
      await tester.runAsync(c.flush);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
