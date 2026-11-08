import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/app_controller.dart';
import 'package:microfantasy/main.dart';
import 'package:microfantasy/screens/cut/cut_screen.dart';
import 'package:microfantasy/widgets/machine_connection_button.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/services/fantasy_designer/local_receiver_service.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(844, 430),
  ]) {
    testWidgets('four screens fit $size and cut controls need no scrolling', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      late AppController c;
      await tester.runAsync(() async {
        c = AppController(
          store: MemoryStore(),
          designer: LocalReceiverService(port: 0, bindAddress: '127.0.0.1'),
        );
        await c.initialize();
      });
      c.simulateX(2);
      await tester.pumpWidget(MicroFantasyApp(controller: c));
      await tester.pump(const Duration(milliseconds: 300));
      final bounds = Rect.fromLTWH(0, 24, size.width, size.height - 48);
      expect(find.byType(MachineConnectionButton), findsOneWidget);
      for (final finder in [
        find.byKey(const ValueKey('machine-connection-action')),
        for (var i = 0; i < 4; i++) find.byKey(ValueKey('app-tab-$i')),
      ]) {
        final rect = tester.getRect(finder);
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(bounds.contains(rect.topLeft), isTrue, reason: '$finder: $rect');
        expect(
          bounds.contains(rect.bottomRight),
          isTrue,
          reason: '$finder: $rect',
        );
      }
      expect(
        find.descendant(
          of: find.byType(CutScreen),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('x-position-bar'))).height,
        88,
      );
      for (final finder in [
        find.byKey(const ValueKey('x-position-bar')),
        find.text('Anterior'),
        find.text('Siguiente'),
      ]) {
        final rect = tester.getRect(finder);
        expect(bounds.contains(rect.topLeft), isTrue, reason: '$finder: $rect');
        expect(
          bounds.contains(rect.bottomRight),
          isTrue,
          reason: '$finder: $rect',
        );
      }
      expect(find.text('Paso 1 de 6'), findsOneWidget);
      expect(find.text('Profundidad'), findsNothing);
      expect(find.text('Ángulo R'), findsOneWidget);
      await tester.tap(find.text('Siguiente'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Paso 2 de 6'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('app-tab-1')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Calibración R'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('app-tab-2')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Calibración X'), findsAtLeastNWidgets(1));
      expect(find.byKey(const ValueKey('x-travel-reading')), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('app-tab-3')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Modo simulación'), findsNothing);
      expect(find.text('Importar archivo JSON'), findsNothing);
      expect(find.text('Dirección X'), findsNothing);
      expect(find.text('Perfil activo'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Opciones avanzadas'),
        450,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Opciones avanzadas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Opciones avanzadas'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Modo simulación'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(c.flush);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets('connection, tabs and X controls stay accessible at 568x320', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    late AppController c;
    await tester.runAsync(() async {
      c = AppController(
        store: MemoryStore(),
        designer: LocalReceiverService(port: 0, bindAddress: '127.0.0.1'),
      );
      await c.initialize();
    });
    await tester.pumpWidget(MicroFantasyApp(controller: c));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('app-tab-2')));
    await tester.pump(const Duration(milliseconds: 300));
    // The short landscape check covers chrome and the scrollable X screen;
    // it does not impose a new minimum-height requirement on the cutting ruler.
    tester.view.physicalSize = const Size(568, 320);
    await tester.pumpAndSettle();
    const bounds = Rect.fromLTWH(0, 24, 568, 272);
    for (final finder in [
      find.byKey(const ValueKey('machine-connection-action')),
      for (var i = 0; i < 4; i++) find.byKey(ValueKey('app-tab-$i')),
    ]) {
      final rect = tester.getRect(finder);
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(bounds.contains(rect.topLeft), isTrue);
      expect(bounds.contains(rect.bottomRight), isTrue);
    }
    final capture = find.byKey(const ValueKey('x-capture-center'));
    await tester.ensureVisible(capture);
    await tester.pumpAndSettle();
    expect(capture.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(c.flush);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
