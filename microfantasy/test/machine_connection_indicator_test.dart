import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/theme.dart';
import 'package:microfantasy/widgets/machine_connection_indicator.dart';

void main() {
  final indicator = find.byType(MachineConnectionIndicator);
  dynamic painter(WidgetTester tester) => tester
      .widget<CustomPaint>(
        find.descendant(of: indicator, matching: find.byType(CustomPaint)),
      )
      .painter;

  Future<void> mount(
    WidgetTester tester, {
    bool connected = false,
    bool simulation = false,
    bool reducedMotion = false,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: microTheme(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Scaffold(
          body: Center(
            child: MachineConnectionIndicator(
              connected: connected,
              simulation: simulation,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('status has no button or tap action', (tester) async {
    final semantics = tester.ensureSemantics();
    await mount(tester);
    expect(find.byType(TextButton), findsNothing);
    final node = tester.widget<Semantics>(
      find.byKey(const ValueKey('machine-connection-indicator')),
    );
    expect(node.properties.button, isNot(true));
    expect(node.properties.onTap, isNull);
    expect(find.text('Buscando…'), findsOneWidget);
    await tester.tap(indicator);
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('search moves continuously; arrival emits one finite burst', (
    tester,
  ) async {
    await mount(tester);
    final start = painter(tester).progress;
    await tester.pump(const Duration(milliseconds: 400));
    expect(painter(tester).progress, isNot(start));
    final searching = painter(tester).progress;
    await mount(tester); // A telemetry rebuild must not restart the animation.
    expect(painter(tester).progress, searching);
    await mount(tester, connected: true);
    expect(find.text('Conectada'), findsOneWidget);
    expect(painter(tester).progress, 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(painter(tester).progress, inExclusiveRange(0, 1));
    final canvas = _Lines();
    painter(tester).paint(canvas, const Size(44, 44));
    expect(canvas.lines.length, 11);
    expect(
      canvas.lines.every((line) => line.end.distance > line.start.distance),
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(painter(tester).progress, 1);
    await mount(tester, connected: true);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await mount(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(painter(tester).progress, inExclusiveRange(0, 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('simulation and reduced motion do not loop', (tester) async {
    await mount(tester, simulation: true);
    await tester.pumpAndSettle();
    expect(find.text('Simulación'), findsOneWidget);
    expect(painter(tester).active, false);
    await mount(tester, reducedMotion: true);
    await tester.pumpAndSettle();
    expect(painter(tester).active, false);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

class _Lines implements Canvas {
  final lines = <({Offset start, Offset end})>[];
  @override
  void drawLine(Offset a, Offset b, Paint paint) => lines.add((
    start: a - const Offset(22, 22),
    end: b - const Offset(22, 22),
  ));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
