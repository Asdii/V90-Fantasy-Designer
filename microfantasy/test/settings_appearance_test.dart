import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/app_controller.dart';
import 'package:microfantasy/app/theme.dart';
import 'package:microfantasy/models/app_settings.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/screens/settings/settings_screen.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service.dart';
import 'package:microfantasy/widgets/common.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}

void main() {
  test('all appearances have readable surface and button text', () {
    expect(AppearanceTheme.values, hasLength(9));
    for (final appearance in AppearanceTheme.values) {
      final theme = microTheme(appearance);
      final colors = theme.colorScheme;
      expect(
        colors.brightness,
        {
              AppearanceTheme.dark,
              AppearanceTheme.midnight,
              AppearanceTheme.lagoon,
              AppearanceTheme.amethyst,
            }.contains(appearance)
            ? Brightness.dark
            : Brightness.light,
      );
      for (final pair in [
        (colors.onSurface, colors.surface),
        (colors.onSurfaceVariant, colors.surface),
        (colors.onSurface, theme.scaffoldBackgroundColor),
        (colors.onPrimary, colors.primary),
      ]) {
        expect(
          contrast(pair.$1, pair.$2),
          greaterThanOrEqualTo(4.5),
          reason: appearance.name,
        );
      }
    }
  });

  test(
    'Claro and AMOLED Oscuro precede Midnight; dark has pure white controls',
    () {
      expect(AppearanceTheme.values.take(3), [
        AppearanceTheme.light,
        AppearanceTheme.dark,
        AppearanceTheme.midnight,
      ]);
      final theme = microTheme(AppearanceTheme.dark);
      expect(theme.scaffoldBackgroundColor, Colors.black);
      expect(theme.colorScheme.onSurface, Colors.white);
      expect(theme.colorScheme.primary, Colors.white);
      expect(theme.colorScheme.onPrimary, Colors.black);
    },
  );

  testWidgets(
    'settings order and readiness remain simple; themes can be selected',
    (tester) async {
      tester.view.physicalSize = const Size(720, 8000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late AppController controller;
      await tester.runAsync(() async {
        controller = AppController(
          store: MemoryStore(),
          designer: LocalReceiverService(port: 0, bindAddress: '127.0.0.1'),
        );
        await controller.initialize();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: microTheme(),
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => SettingsScreen(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final sections = tester
          .widgetList<Section>(find.byType(Section))
          .map((s) => s.title)
          .toList();
      expect(sections, [
        'Máquina',
        'V90 Fantasy Designer',
        'Preferencias',
        'Temas',
        'Datos',
        'Actualizaciones',
      ]);
      expect(find.text('Lista para recibir diseños'), findsOneWidget);
      expect(find.textContaining('/api/v1'), findsNothing);
      expect(find.text('Copiar dirección'), findsNothing);
      expect(find.text('Opciones avanzadas'), findsOneWidget);
      expect(find.text('A tu manera'), findsNothing);
      expect(find.textContaining('Elige el ambiente'), findsNothing);
      final lightY = tester.getTopLeft(find.text('Claro')).dy;
      final darkY = tester.getTopLeft(find.text('Oscuro')).dy;
      final nightY = tester.getTopLeft(find.text('Midnight')).dy;
      expect(lightY, lessThanOrEqualTo(darkY));
      expect(darkY, lessThanOrEqualTo(nightY));
      await tester.tap(find.text('Midnight'));
      await tester.pumpAndSettle();
      expect(controller.settings.appearance, AppearanceTheme.midnight);
      expect(tester.takeException(), isNull);
      await tester.runAsync(controller.flush);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
