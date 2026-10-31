// Optional visual QA: flutter test --update-goldens tool/visual_check_test.dart
// Set MICROFANTASY_QA_FONT to a local TTF to capture readable device-like text.
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/app_controller.dart';
import 'package:microfantasy/main.dart';
import 'package:microfantasy/models/cutting_job.dart';
import 'package:microfantasy/models/app_settings.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service.dart';

void main() {
  testWidgets('capture three mobile screens', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late AppController c;
    await tester.runAsync(() async {
      final font = Platform.environment['MICROFANTASY_QA_FONT'];
      if (font != null) {
        final bytes = await File(font).readAsBytes();
        await (FontLoader(
          'Roboto',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        await (FontLoader(
          'monospace',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
      final icons = Platform.environment['MICROFANTASY_QA_ICONS'];
      if (icons != null) {
        final bytes = await File(icons).readAsBytes();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
      c = AppController(
        store: MemoryStore(),
        designer: LocalReceiverService(port: 0, bindAddress: '127.0.0.1'),
      );
      await c.initialize();
      await c.updateSettings(c.settings.copyWith(haptics: false));
      // Real controller methods populate a nonzero circular calibration.
      for (var i = 0; i < 12; i++) {
        c.simulateX(
          12 + <double>[0, .1, .2, .3, .2, .1, 0, -.1, -.2, -.3, -.2, -.1][i],
        );
        await Future<void>.delayed(Duration.zero);
        c.saveCalibrationPoint();
        c.nextAngle();
      }
      c.simulateX(2.03);
      await c.flush();
    });
    await tester.pumpWidget(MicroFantasyApp(controller: c));
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(
      find.byType(MicroFantasyApp),
      matchesGoldenFile('../build/qa/cut.png'),
    );
    await tester.tap(find.text('Calibración'));
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(
      find.byType(MicroFantasyApp),
      matchesGoldenFile('../build/qa/calibration.png'),
    );
    await tester.tap(find.text('Configuración'));
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(
      find.byType(MicroFantasyApp),
      matchesGoldenFile('../build/qa/settings.png'),
    );
    await tester.runAsync(() async {
      final json = jsonDecode(
        await File('examples/v90-cut-helper.json').readAsString(),
      );
      await c.receiveJob(CuttingJob.fromJson(Map<String, Object?>.from(json)));
      c.acceptPending();
      await c.flush();
    });
    await tester.tap(find.text('Corte'));
    await tester.pump(const Duration(milliseconds: 600));
    c.simulateX(c.correctedTarget + .005);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MicroFantasyApp),
      matchesGoldenFile('../build/qa/cut-v90.png'),
    );
    await tester.runAsync(
      () => c.updateSettings(
        c.settings.copyWith(appearance: AppearanceTheme.midnight),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MicroFantasyApp),
      matchesGoldenFile('../build/qa/cut-midnight.png'),
    );
    tester.view.physicalSize = const Size(360, 640);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MicroFantasyApp),
      matchesGoldenFile('../build/qa/cut-compact.png'),
    );
    tester.view.physicalSize = const Size(390, 844);
    await tester.runAsync(
      () => c.updateSettings(
        c.settings.copyWith(appearance: AppearanceTheme.atelier),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Abrir Cut Helper'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Abrir Cut Helper'));
    await tester.pumpAndSettle();
    expect(find.text('Cut Helper · V90'), findsOneWidget);
    await expectLater(
      find.byType(Dialog),
      matchesGoldenFile('../build/qa/v90-cut-helper.png'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
