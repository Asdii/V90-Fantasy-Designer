// Optional: flutter test --update-goldens tool/boot_visual_check_test.dart
// MICROFANTASY_QA_FONT and MICROFANTASY_QA_ICONS can supply local font files.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/app_controller.dart';
import 'package:microfantasy/main.dart';
import 'package:microfantasy/models/app_settings.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/repositories/settings_repository.dart';
import 'package:microfantasy/services/esp32/mock_esp32_service.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service.dart';

void main() {
  testWidgets('capture boot notice, X travel and radial connection indicator', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final mock = MockEsp32Service();
    final store = MemoryStore();
    late AppController c;
    await tester.runAsync(() async {
      for (final entry in {
        'Roboto': 'MICROFANTASY_QA_FONT',
        'monospace': 'MICROFANTASY_QA_FONT',
        'MaterialIcons': 'MICROFANTASY_QA_ICONS',
      }.entries) {
        final path = Platform.environment[entry.value];
        if (path == null) continue;
        final bytes = await File(path).readAsBytes();
        await (FontLoader(
          entry.key,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
      await SettingsRepository(
        store,
      ).save(AppSettings(simulation: false, haptics: false));
      c = AppController(
        store: store,
        designer: LocalReceiverService(port: 0, bindAddress: '127.0.0.1'),
        hardwareFactory: (_) => mock,
      );
      await c.initialize();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await c.flush();
    });
    await tester.pumpWidget(MicroFantasyApp(controller: c));
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(
      find.byType(MicroFantasyApp),
      matchesGoldenFile('../build/qa/boot-notice.png'),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Calibrar X'));
      await c.flush();
      await c.captureXCenter();
      mock.setPosition(35);
      await Future<void>.delayed(Duration.zero);
      await c.captureXPositive();
      mock.setPosition(-25);
      await Future<void>.delayed(Duration.zero);
      await c.captureXNegative();
      mock.setPosition(12);
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump(const Duration(milliseconds: 250));
    await expectLater(
      find.byType(MicroFantasyApp),
      matchesGoldenFile('../build/qa/boot-x-travel.png'),
    );
    await tester.runAsync(mock.disconnect);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 700));
    await expectLater(
      find.byType(MicroFantasyApp),
      matchesGoldenFile('../build/qa/boot-searching.png'),
    );
    await tester.runAsync(mock.connect);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(
      find.byType(MicroFantasyApp),
      matchesGoldenFile('../build/qa/boot-connected.png'),
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(c.flush);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
