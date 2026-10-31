import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/app_controller.dart';
import 'package:microfantasy/models/models.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/screens/cut/cut_screen.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service.dart';
import 'package:microfantasy/widgets/x_position_guide.dart';

const _mainBar = ValueKey('x-position-bar');
const _precisionBar = ValueKey('x-precision-bar');

// Inspect the values actually handed to the painters, not animation internals.
dynamic _painter(WidgetTester tester, [Key key = _mainBar]) =>
    tester.widget<CustomPaint>(find.byKey(key)).painter;

Future<void> _guide(
  WidgetTester tester,
  double? actual, {
  double target = 0,
  double tolerance = 0.05,
  String smoothing = 'off',
  bool centimeters = false,
  ThemeData? theme,
}) => tester.pumpWidget(
  MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          child: XPositionGuide(
            actualMm: actual,
            targetMm: target,
            toleranceMm: tolerance,
            smoothing: smoothing,
            centimeters: centimeters,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  group('X guide', () {
    for (final smoothing in ['off', 'light', 'medium']) {
      testWidgets(
        'zoom finishes during 50 Hz telemetry with $smoothing smoothing',
        (tester) async {
          await _guide(tester, 2, smoothing: smoothing);
          await _guide(tester, 0.7, smoothing: smoothing);
          expect(_painter(tester).range, 5);
          await tester.pump(const Duration(milliseconds: 120));
          expect(_painter(tester).range, allOf(greaterThan(1), lessThan(5)));

          for (var packet = 0; packet < 30; packet++) {
            final actual = 0.69 - packet * 0.001;
            await _guide(tester, actual, smoothing: smoothing);
            expect(
              find.text('${actual.toStringAsFixed(3)} mm'),
              findsOneWidget,
            );
            // The label is raw; every visual mode interpolates sensor packets.
            expect(_painter(tester).actual, greaterThanOrEqualTo(actual));
            await tester.pump(const Duration(milliseconds: 20));
          }
          expect(_painter(tester).range, 1);
          expect(find.text('En tolerancia'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('zoom settles despite noise at both scale thresholds', (
      tester,
    ) async {
      await _guide(tester, 2);
      await _guide(tester, 0.79);
      for (var packet = 0; packet < 32; packet++) {
        await tester.pump(const Duration(milliseconds: 20));
        await _guide(tester, packet.isEven ? 0.81 : 0.79);
      }
      expect(_painter(tester).range, 1);

      await _guide(tester, 0.149);
      for (var packet = 0; packet < 32; packet++) {
        await tester.pump(const Duration(milliseconds: 20));
        await _guide(tester, packet.isEven ? 0.151 : 0.149);
      }
      expect(_painter(tester).range, 0.4);
      await _guide(tester, 0.19);
      await tester.pump(const Duration(milliseconds: 640));
      expect(_painter(tester).range, 1);
      await _guide(tester, 0.91);
      await tester.pump(const Duration(milliseconds: 640));
      expect(_painter(tester).range, 5);
    });

    testWidgets('zoom reverses continuously when its destination changes', (
      tester,
    ) async {
      await _guide(tester, 2);
      await _guide(tester, 0.6);
      await tester.pump(const Duration(milliseconds: 100));
      final double before = _painter(tester).range as double;
      await _guide(tester, 1.2);
      expect(_painter(tester).range, before);
      final marker = _painter(tester).actual;
      expect(marker, isNot(1.2));
      await tester.pump(const Duration(milliseconds: 120));
      expect(_painter(tester).range, greaterThan(before));
      expect(_painter(tester).range, lessThan(5));
      await tester.pump(const Duration(milliseconds: 520));
      expect(_painter(tester).range, 5);
    });

    testWidgets(
      'marker crosses smoothly while raw status and measurements remain immediate',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await _guide(tester, -0.4, smoothing: 'medium');
          await _guide(tester, -0.2, smoothing: 'medium');
          expect(find.text('-0.200 mm'), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 60));
          expect(
            _painter(tester).actual,
            allOf(greaterThan(-0.4), lessThan(-0.2)),
          );

          // Jump over the entire band, then enter and leave it on both sides.
          for (final actual in [0.08, -0.08, 0.05, 0.051, -0.05, -0.051]) {
            await _guide(tester, actual, smoothing: 'medium');
            final arrived = actual.abs() <= 0.05;
            final status = arrived
                ? 'En tolerancia'
                : actual < 0
                ? 'Mover hacia +X'
                : 'Mover hacia −X';
            expect(find.text(status), findsOneWidget);
            expect(
              find.bySemanticsLabel(
                'Posición X. Actual ${actual.toStringAsFixed(3)} mm. '
                'Objetivo 0.000 mm. $status.',
              ),
              findsOneWidget,
            );
            final before = _painter(tester).actual as double;
            await tester.pump(const Duration(milliseconds: 60));
            final during = _painter(tester).actual as double;
            expect(
              (during - actual).abs(),
              lessThanOrEqualTo((before - actual).abs()),
            );
            expect(_painter(tester, _precisionBar).actual, during);
            await tester.pump(const Duration(milliseconds: 180));
            expect(_painter(tester).actual, actual);
          }
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets('every mode eases marker packets without restarting zoom', (
      tester,
    ) async {
      for (final level in ['off', 'light', 'medium', 'unknown']) {
        await _guide(tester, 2, smoothing: level);
        await tester.pumpAndSettle();
        await _guide(tester, .6, smoothing: level);
        expect(_painter(tester).actual, 2);
        expect(find.text('0.600 mm'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 40));
        expect(_painter(tester).actual, allOf(greaterThan(.6), lessThan(2)));
        await tester.pump(const Duration(milliseconds: 600));
        expect(_painter(tester).actual, .6);
        expect(_painter(tester).range, 1);
      }
    });

    testWidgets('ruler center labels are actual targets in mm and cm', (
      tester,
    ) async {
      for (final target in [15.2, -3.415, 0.0]) {
        await _guide(tester, target, target: target);
        expect(
          _painter(tester).tickLabel(0.0),
          '${target.toStringAsFixed(3)} mm',
        );
        expect(
          _painter(tester, _precisionBar).tickLabel(0.0),
          '${target.toStringAsFixed(3)} mm',
        );
        expect(
          _painter(tester).tickLabel(-.1),
          '${(target - .1).toStringAsFixed(3)} mm',
        );
        await _guide(tester, target, target: target, centimeters: true);
        expect(
          _painter(tester).tickLabel(0.0),
          '${(target / 10).toStringAsFixed(4)} cm',
        );
      }
    });

    testWidgets(
      'inset fades above a stationary bar and tolerates edge jitter',
      (tester) async {
        await _guide(tester, 2);
        final barRect = tester.getRect(find.byKey(_mainBar));
        final guideSize = tester.getSize(find.byType(XPositionGuide));
        expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
          0,
        );
        await _guide(tester, 0.08);
        await tester.pump(const Duration(milliseconds: 60));
        final fade = tester.widget<FadeTransition>(
          find.descendant(
            of: find.byType(AnimatedOpacity),
            matching: find.byType(FadeTransition),
          ),
        );
        expect(fade.opacity.value, allOf(greaterThan(0), lessThan(1)));
        expect(
          tester.getRect(find.byKey(_precisionBar)).bottom,
          lessThan(barRect.top),
        );
        expect(tester.getRect(find.byKey(_mainBar)), barRect);
        expect(tester.getSize(find.byType(XPositionGuide)), guideSize);
        expect(
          _painter(tester, _precisionBar).range,
          lessThan(_painter(tester).range),
        );
        expect(_painter(tester, _precisionBar).tolerance, 0.05);
        expect(find.byKey(const ValueKey('x-zoom-connector')), findsOneWidget);

        await _guide(tester, 0.11);
        expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
          1,
        );
        await _guide(tester, 0.2);
        expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
          0,
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byKey(_mainBar)), barRect);
        expect(tester.getSize(find.byType(XPositionGuide)), guideSize);
      },
    );

    testWidgets('invalid input immediately clears both markers and success', (
      tester,
    ) async {
      for (final actual in <double?>[null, double.nan, double.infinity]) {
        await _guide(tester, 0, smoothing: 'medium');
        expect(find.text('En tolerancia'), findsOneWidget);
        await _guide(tester, actual, smoothing: 'medium');
        expect(find.text('Sin conexión'), findsOneWidget);
        for (final key in [_mainBar, _precisionBar]) {
          expect(_painter(tester, key).actual, isNull);
        }
        expect(find.text('En tolerancia'), findsNothing);
        expect(
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
          0,
        );
      }
      for (final tolerance in [-0.1, double.nan, double.infinity]) {
        await _guide(tester, 0, tolerance: tolerance);
        expect(find.text('Objetivo o tolerancia no válido'), findsOneWidget);
        expect(_painter(tester).actual, isNull);
        expect(_painter(tester, _precisionBar).actual, isNull);
      }
      await _guide(tester, 0, target: double.nan);
      expect(find.text('Objetivo o tolerancia no válido'), findsOneWidget);
      expect(_painter(tester).actual, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'target, tolerance and display units retain exact mm semantics',
      (tester) async {
        await _guide(tester, 0.08, smoothing: 'medium');
        await _guide(tester, 0.08, tolerance: 0.1, smoothing: 'medium');
        expect(find.text('En tolerancia'), findsOneWidget);
        expect(_painter(tester).range, greaterThanOrEqualTo(0.8));
        expect(_painter(tester).actual, 0.08);
        await _guide(tester, 0.08, target: 1, smoothing: 'medium');
        expect(find.text('Mover hacia +X'), findsOneWidget);
        expect(_painter(tester).actual, 0.08);

        await _guide(tester, 0.05, centimeters: true);
        expect(find.text('0.0050 cm'), findsOneWidget);
        expect(find.text('En tolerancia'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(_painter(tester).actual, 0.05);
        expect(_painter(tester).tolerance, 0.05);
        expect(_painter(tester, _precisionBar).tolerance, 0.05);
        await _guide(tester, 0, tolerance: 0);
        expect(find.text('En tolerancia'), findsOneWidget);
        await _guide(tester, 0.0001, tolerance: 0);
        expect(find.text('En tolerancia'), findsNothing);
        expect(_painter(tester).tolerance, 0);
      },
    );

    testWidgets('guide and painters update with the host theme', (
      tester,
    ) async {
      final light = ThemeData(colorSchemeSeed: Colors.teal);
      final dark = ThemeData(
        colorSchemeSeed: Colors.amber,
        brightness: Brightness.dark,
      );
      await _guide(tester, 0, theme: light);
      final before = _painter(tester);
      await _guide(tester, 0, theme: dark);
      await tester.pumpAndSettle();
      expect(_painter(tester).colors, dark.colorScheme);
      expect(_painter(tester, _precisionBar).colors, dark.colorScheme);
      expect(_painter(tester).shouldRepaint(before), isTrue);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.check_circle_outline)).color,
        const Color(0xFF7CD9A6),
      );
    });

    testWidgets(
      'raw boundary status and target stay green with black markers in every theme',
      (tester) async {
        const green = Color(0xFF227A50);
        for (final accent in [Colors.blue, Colors.purple, Colors.brown]) {
          final theme = ThemeData(colorSchemeSeed: accent);
          await _guide(tester, -0.06, smoothing: 'medium', theme: theme);
          await tester.pumpAndSettle();
          for (final actual in [-0.05, -0.0501, 0.0501, 0.05]) {
            await _guide(tester, actual, smoothing: 'medium', theme: theme);
            final arrived = actual.abs() <= 0.05;
            if (arrived) {
              expect(
                tester.widget<Text>(find.text('En tolerancia')).style?.color,
                green,
              );
              expect(
                tester
                    .widget<Icon>(find.byIcon(Icons.check_circle_outline))
                    .color,
                green,
              );
            } else {
              expect(find.text('En tolerancia'), findsNothing);
              expect(find.byIcon(Icons.check_circle_outline), findsNothing);
            }
            for (final key in [_mainBar, _precisionBar]) {
              // Success already reflects the raw boundary, although the
              // marker is allowed to travel to that reading over a few frames.
              Rect? track;
              expect(
                tester.renderObject(find.byKey(key)),
                paints
                  ..something((method, arguments) {
                    if (method != #drawRRect) return false;
                    track = (arguments.first as RRect).outerRect;
                    return true;
                  })
                  ..something((method, arguments) {
                    if (method != #drawRect) return false;
                    final band = arguments.first as Rect;
                    final paint = arguments[1] as Paint;
                    expect(paint.shader, isNotNull);
                    expect(
                      (band.center - track!.center).distance,
                      lessThan(1e-9),
                    );
                    expect(
                      band.width / track!.width,
                      closeTo(
                        0.05 / (_painter(tester, key).range as double),
                        1e-9,
                      ),
                    );
                    return true;
                  })
                  ..line(color: green)
                  ..path(color: Colors.black),
              );
            }
            await tester.pump(const Duration(milliseconds: 20));
          }
        }
      },
    );
  });

  testWidgets(
    'small-phone Cut offers V90 and demo, angle R and no profile label',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AppController(
        store: MemoryStore(),
        designer: LocalReceiverService(),
      );
      addTearDown(controller.dispose);
      controller.profiles = [
        CalibrationProfile(
          id: 'single',
          name: 'Private calibration label',
          referenceX: 0,
          points: [
            CalibrationPoint(angleR: 0, x: 0),
            CalibrationPoint(angleR: 180, x: 0.1),
          ],
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => CutScreen(controller: controller),
            ),
          ),
        ),
      );
      expect(find.textContaining('V90 Fantasy Designer'), findsOneWidget);
      expect(find.textContaining('La recepción está activa'), findsOneWidget);
      expect(find.textContaining('Recibir por Wi-Fi'), findsNothing);
      expect(find.textContaining('Importar'), findsNothing);
      await tester.tap(find.text('Probar un ejemplo'));
      await tester.pumpAndSettle();
      expect(find.text('Paso 1 de 6'), findsOneWidget);
      expect(find.text('Ángulo R'), findsOneWidget);
      expect(find.text('Profundidad'), findsNothing);
      expect(find.text('Compensación activa'), findsOneWidget);
      expect(find.textContaining('Private calibration label'), findsNothing);
      expect(find.byTooltip('Cambiar patrón'), findsNothing);
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Paso 2 de 6'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await controller.flush();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
