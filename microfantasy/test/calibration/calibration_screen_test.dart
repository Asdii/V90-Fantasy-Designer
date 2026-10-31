import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/app_controller.dart';
import 'package:microfantasy/app/theme.dart';
import 'package:microfantasy/models/calibration_profile.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/screens/calibration/calibration_screen.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service_stub.dart';

void main() {
  final feedback = find.byKey(const ValueKey('calibration-saved-feedback'));
  double opacity(WidgetTester tester) =>
      tester.widget<FadeTransition>(feedback).opacity.value;

  Future<void> mount(WidgetTester tester, AppController c) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: microTheme(),
        home: Scaffold(body: CalibrationScreen(controller: c)),
      ),
    );
  }

  testWidgets('reference-first controls and persisted inline feedback', (
    tester,
  ) async {
    final store = _DelayedStore();
    final c = _Controller(store);
    addTearDown(c.dispose);
    c.settings = c.settings.copyWith(autoAdvance: true);
    await mount(tester, c);
    expect(find.text('Un montaje, una referencia'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('Guardar calibración'), findsNothing);
    expect(find.text('Nuevo perfil'), findsNothing);
    for (final label in ['Anterior', 'Siguiente']) {
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, label))
            .onPressed,
        isNull,
      );
    }
    expect(opacity(tester), 0);
    await tester.tap(find.text('Establecer referencia en 0°'));
    await tester.pump();
    expect(c.calibrationAngle, 30);
    expect(c.calibrationSavedId, 0);
    expect(opacity(tester), 0);
    store.pending.complete();
    await tester.pump();
    await c.flush();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('0° guardado'), findsOneWidget);
    expect(opacity(tester), 1);
    expect(find.byType(SnackBar), findsNothing);
    expect(c.noticeId, 0);
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .ancestor(of: feedback, matching: find.byType(IgnorePointer))
                .first,
          )
          .ignoring,
      isTrue,
    );
    await tester.tap(find.text('Siguiente'));
    await tester.pump();
    expect(c.calibrationAngle, 60);
    expect(find.text('0° guardado'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(opacity(tester), 0);

    // A second save restarts the pulse; unmounting during it cancels the ticker.
    await tester.tap(find.text('Guardar punto'));
    await tester.pump();
    await c.flush();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('60° guardado'), findsOneWidget);
    expect(opacity(tester), 1);
    await tester.pumpWidget(const SizedBox.shrink());
    c.nextAngle();
    await c.flush();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed persistence never shows the saved animation', (
    tester,
  ) async {
    final store = _DelayedStore()..fail = true;
    final c = _Controller(store);
    addTearDown(c.dispose);
    await mount(tester, c);
    await tester.tap(find.text('Establecer referencia en 0°'));
    await tester.pump();
    store.pending.complete();
    await tester.pump();
    await c.flush();
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.calibrationSavedId, 0);
    expect(opacity(tester), 0);
  });

  testWidgets('deleting zero requires confirmation and clears every point', (
    tester,
  ) async {
    final c = _Controller(MemoryStore());
    addTearDown(c.dispose);
    c.saveCalibrationPoint();
    c.nextAngle();
    c.saveCalibrationPoint();
    c.previousAngle();
    await c.flush();
    await mount(tester, c);
    // Mounting a screen must not replay an earlier save notification.
    expect(opacity(tester), 0);
    await tester.ensureVisible(find.text('Eliminar referencia'));
    await tester.tap(find.text('Eliminar referencia'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar referencia de 0°'), findsOneWidget);
    expect(c.profile.points, hasLength(2));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(c.profile.points, hasLength(2));
    await tester.tap(find.text('Eliminar referencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await c.flush();
    expect(c.profile.points, isEmpty);
    expect(c.calibrationAngle, 0);
    expect(c.hasCalibrationReference, isFalse);
    expect(find.text('Establecer referencia en 0°'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Controller extends AppController {
  _Controller(KeyValueStore store)
    : super(store: store, designer: LocalReceiverService()) {
    profiles = [
      CalibrationProfile(
        id: 'principal',
        name: 'Calibración',
        referenceX: 0,
        points: [],
      ),
    ];
  }

  @override
  double? get actualX => 12;
}

class _DelayedStore extends MemoryStore {
  final pending = Completer<void>();
  bool fail = false;

  @override
  Future<void> setString(String key, String value) async {
    await pending.future;
    if (fail) throw StateError('Write failed');
    await super.setString(key, value);
  }
}
