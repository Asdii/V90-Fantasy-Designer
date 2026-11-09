import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/main.dart';
import 'package:microfantasy/models/app_settings.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/repositories/settings_repository.dart';
import 'package:microfantasy/screens/x_calibration/x_calibration_screen.dart';
import 'machine_boot_test.dart' show openPhone;
import 'support/boot_machine.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 430),
  ]) {
    testWidgets('persistent boot notice fits $size and opens X calibration', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final store = MemoryStore();
      final board = BootMachine();
      final c = await tester.runAsync(() async {
        await SettingsRepository(
          store,
        ).save(AppSettings(simulation: false, haptics: false));
        return openPhone(store, board);
      });
      await tester.pumpWidget(MicroFantasyApp(controller: c!));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('La máquina se encendió o reinició'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      for (final finder in [
        find.text('Calibrar X'),
        find.text('Anterior'),
        find.text('Siguiente'),
        find.byKey(const ValueKey('x-position-bar')),
      ]) {
        final rect = tester.getRect(finder);
        expect(rect.top, greaterThanOrEqualTo(24));
        expect(rect.bottom, lessThanOrEqualTo(size.height - 24));
      }
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await tester.tap(find.text('Calibrar X'));
        await c.flush();
      });
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(XCalibrationScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('machine-boot-notice')), findsNothing);
      final tab1 = find.descendant(
        of: find.byKey(const ValueKey('app-tab-1')),
        matching: find.textContaining('X'),
      );
      final tab2 = find.descendant(
        of: find.byKey(const ValueKey('app-tab-2')),
        matching: find.textContaining('R'),
      );
      expect(tab1, findsOneWidget);
      expect(tab2, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
