import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/app_controller.dart';
import 'package:microfantasy/app/theme.dart';
import 'package:microfantasy/models/x_axis_calibration.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/screens/x_calibration/x_calibration_screen.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service_stub.dart';

void main() {
  Finder keyed(String key) => find.byKey(ValueKey(key));

  Future<void> mount(
    WidgetTester tester,
    _Controller c, {
    Size size = const Size(320, 568),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: microTheme(),
        home: Scaffold(body: XCalibrationScreen(controller: c)),
      ),
    );
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(keyed(key));
    await tester.pumpAndSettle();
    await tester.tap(keyed(key));
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, String key) =>
      tester.widget<ButtonStyleButton>(keyed(key)).onPressed != null;

  testWidgets(
    'guided center, negative, positive uses only fresh controller values',
    (tester) async {
      final c = _Controller();
      await mount(tester, c);
      await tap(tester, 'x-travel-select-positive');
      expect(enabled(tester, 'x-capture-positive'), isFalse);
      await tap(tester, 'x-travel-select-center');
      await tap(tester, 'x-capture-center');
      expect(c.centerCalls, 1);
      expect(c.xAxisReady, isTrue);
      expect(c.axis!.isComplete, isFalse);
      expect(find.text('X actual: 0.000 mm'), findsOneWidget);
      expect(enabled(tester, 'x-capture-negative'), isTrue);
      expect(find.text('Guardar tope +'), findsOneWidget);
      c.reading = -25;
      c.publish();
      await tester.pump();
      await tap(tester, 'x-capture-negative');
      expect(c.axis!.negativeMm, -25);
      expect(enabled(tester, 'x-capture-positive'), isTrue);
      expect(find.text('Guardar tope −'), findsOneWidget);
      c.reading = 75;
      c.publish();
      await tester.pump();
      await tap(tester, 'x-capture-positive');
      expect(c.axis!.travelMm, 100);
      expect(
        find.text('3 de 3 referencias guardadas · recorrido completo'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final positive in [false, true]) {
    testWidgets(
      'reboot requires explicit confirmation at ${positive ? '+' : '−'} stop',
      (tester) async {
        final c = _Controller()..axis = _axis(negative: -25, positive: 75);
        await mount(tester, c, size: const Size(568, 320));
        expect(find.text('Referencia pendiente'), findsOneWidget);
        expect(keyed('x-travel-live-marker'), findsNothing);
        await tap(tester, 'x-travel-select-negative');
        expect(c.references, isEmpty);
        expect(enabled(tester, 'x-capture-negative'), isFalse);
        expect(
          find.descendant(
            of: keyed(
              positive ? 'x-reference-positive' : 'x-reference-negative',
            ),
            matching: find.text('Estoy en el tope ${positive ? '−' : '+'}'),
          ),
          findsOneWidget,
        );
        await tap(
          tester,
          positive ? 'x-reference-positive' : 'x-reference-negative',
        );
        expect(c.references, [positive]);
        expect(c.centerCalls, 0);
        expect(c.xAxisReady, isTrue);
        expect(c.reading, positive ? 75 : -25);
        expect(keyed('x-travel-live-marker'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a draft restores only its saved end and allows finishing', (
    tester,
  ) async {
    final c = _Controller()..axis = _axis(negative: -40);
    await mount(tester, c);
    expect(keyed('x-reference-positive'), findsNothing);
    await tap(tester, 'x-reference-negative');
    expect(c.xAxisReady, isTrue);
    expect(c.axis!.isComplete, isFalse);
    expect(enabled(tester, 'x-capture-positive'), isTrue);
  });

  testWidgets(
    'failed center stays pending with inline retry and destructive confirmation',
    (tester) async {
      final c = _Controller()..failCenter = true;
      await mount(tester, c);
      await tap(tester, 'x-capture-center');
      expect(c.axis, isNotNull);
      expect(c.xAxisReady, isFalse);
      expect(find.text('Reintentar centro'), findsOneWidget);
      expect(find.text('No se pudo confirmar: sin respuesta'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(keyed('x-reference-negative'), findsNothing);
      expect(keyed('x-reference-positive'), findsNothing);
      await tap(tester, 'x-capture-center');
      expect(find.text('¿Rehacer el centro de X?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(c.centerCalls, 1);
      c.failCenter = false;
      await tap(tester, 'x-capture-center');
      await tester.tap(find.widgetWithText(FilledButton, 'Rehacer centro'));
      await tester.pumpAndSettle();
      expect(c.centerCalls, 2);
      expect(c.xAxisReady, isTrue);
      expect(c.resets, 0);
    },
  );

  testWidgets('unsupported firmware and busy actions disable capture', (
    tester,
  ) async {
    final c = _Controller()..supported = false;
    await mount(tester, c);
    expect(find.textContaining('Actualiza el firmware'), findsOneWidget);
    expect(enabled(tester, 'x-capture-center'), isFalse);
    c.supported = true;
    c.xCalibrationBusy = true;
    c.publish();
    await tester.pump();
    expect(enabled(tester, 'x-capture-center'), isFalse);
    expect(find.text('Confirmando referencia…'), findsOneWidget);
    expect(c.centerCalls, 0);
  });

  testWidgets('center and reset preserve saved ends until confirmed', (
    tester,
  ) async {
    final c = _Controller()
      ..axis = _axis(negative: -25, positive: 75)
      ..anchored = true;
    await mount(tester, c);
    await tap(tester, 'x-travel-select-center');
    await tap(tester, 'x-capture-center');
    expect(c.axis!.isComplete, isTrue);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(c.centerCalls, 0);
    await tap(tester, 'x-reset-calibration');
    expect(c.resets, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar calibración'));
    await tester.pumpAndSettle();
    expect(c.resets, 1);
    expect(c.axis, isNull);
  });
}

AxisCalibration _axis({double? negative, double? positive}) => AxisCalibration(
  deviceId: 'test-machine',
  referenceId: 'test-reference',
  negativeMm: negative,
  positiveMm: positive,
);

class _Controller extends AppController {
  _Controller()
    : super(store: MemoryStore(), designer: LocalReceiverService()) {
    settings = settings.copyWith(simulation: false);
  }
  AxisCalibration? axis;
  bool anchored = false;
  bool supported = true;
  bool failCenter = false;
  double reading = 0;
  int centerCalls = 0;
  int resets = 0;
  final references = <bool>[];
  @override
  AxisCalibration? get xCalibration => axis;
  @override
  bool get machineConnected => true;
  @override
  bool get machineConnecting => false;
  @override
  bool get xReferenceSupported => supported;
  @override
  bool get xAxisReady => anchored;
  @override
  bool get xNeedsReference => axis != null && !anchored;
  @override
  double? get sensorX => reading;
  void publish() => notifyListeners();
  @override
  Future<void> captureXCenter() async {
    centerCalls++;
    axis = _axis();
    anchored = !failCenter;
    if (anchored) reading = 0;
    xCalibrationMessage = failCenter
        ? 'No se pudo confirmar: sin respuesta'
        : 'Centro guardado';
    publish();
  }

  @override
  Future<void> captureXNegative() async {
    axis = axis!.withStop(positive: false, value: reading);
    publish();
  }

  @override
  Future<void> captureXPositive() async {
    axis = axis!.withStop(positive: true, value: reading);
    publish();
  }

  @override
  Future<void> referenceXAtStop({required bool positive}) async {
    references.add(positive);
    reading = positive ? axis!.positiveMm! : axis!.negativeMm!;
    anchored = true;
    publish();
  }

  @override
  Future<void> resetXCalibration() async {
    resets++;
    axis = null;
    anchored = false;
    publish();
  }
}
