import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/app_controller.dart';
import 'package:microfantasy/main.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service.dart';

void main() {
  testWidgets('three screens work on a small phone and steps stay accessible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late AppController c;
    await tester.runAsync(() async {
      c = AppController(store: MemoryStore(), designer: LocalReceiverService());
      await c.initialize();
    });
    c.simulateX(2);
    await tester.pumpWidget(MicroFantasyApp(controller: c));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('MicroFantasy'), findsOneWidget);
    expect(find.text('Paso 1 de 6'), findsOneWidget);
    await tester.tap(find.text('Siguiente'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Paso 2 de 6'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Calibración'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Un montaje, una referencia'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Configuración'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Modo simulación'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(c.flush);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
