import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/app_controller.dart';
import 'package:microfantasy/main.dart';
import 'package:microfantasy/models/cutting_job.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/screens/cut/cut_screen.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service.dart';
import 'package:microfantasy/widgets/v90_cut_helper.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(844, 430),
  ]) {
    testWidgets('V90 cut content fits $size without scrolling', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      late AppController controller;
      await tester.runAsync(() async {
        controller = AppController(
          store: MemoryStore(),
          designer: LocalReceiverService(port: 0, bindAddress: '127.0.0.1'),
        );
        await controller.initialize();
        final json = jsonDecode(
          await File('examples/v90-cut-helper.json').readAsString(),
        );
        await controller.receiveJob(
          CuttingJob.fromJson(Map<String, Object?>.from(json)),
        );
        controller.acceptPending();
        await controller.flush();
      });
      await tester.pumpWidget(MicroFantasyApp(controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(CutScreen),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      expect(find.textContaining('Desde el centro:'), findsNothing);
      final screen = Rect.fromLTWH(0, 24, size.width, size.height - 48);
      final mainBar = find.byKey(const ValueKey('x-position-bar'));
      expect(tester.getSize(mainBar).height, 88);
      for (final finder in [
        find.byType(V90CutHelper),
        mainBar,
        find.text('Ángulo R'),
        find.text('Anterior'),
        find.text('Siguiente'),
      ]) {
        final rect = tester.getRect(finder);
        expect(rect.width, greaterThan(0));
        expect(rect.height, greaterThan(0));
        expect(
          screen.contains(rect.topLeft),
          isTrue,
          reason: '$finder at $rect',
        );
        expect(
          screen.contains(rect.bottomRight),
          isTrue,
          reason: '$finder at $rect',
        );
      }
      final barBefore = tester.getRect(mainBar);
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(controller.stepIndex, greaterThan(0));
      expect(tester.getRect(mainBar), barBefore);
      expect(tester.takeException(), isNull);
      await tester.runAsync(controller.flush);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
