import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/app/theme.dart';
import 'package:microfantasy/widgets/x_travel_view.dart';

void main() {
  final marker = find.byKey(const ValueKey('x-travel-live-marker'));
  double x(WidgetTester tester, String key) =>
      tester.getCenter(find.byKey(ValueKey(key))).dx;

  Future<void> mount(
    WidgetTester tester,
    XTravelView view, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: microTheme(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: SingleChildScrollView(child: view)),
        ),
      ),
    );
    await tester.pump();
  }

  for (final stops in [(-25.0, 75.0), (-90.0, 10.0)]) {
    testWidgets('asymmetric travel $stops preserves measured geometry', (
      tester,
    ) async {
      final (negative, positive) = stops;
      final position = (negative + positive) / 2;
      await mount(
        tester,
        XTravelView(
          axisReady: true,
          hasCenter: true,
          negativeMm: negative,
          positiveMm: positive,
          positionMm: position,
        ),
      );
      final left = x(tester, 'x-travel-positive-stop');
      final right = x(tester, 'x-travel-negative-stop');
      expect(left, lessThan(right));
      final zero = x(tester, 'x-travel-zero');
      expect(
        (zero - left) / (right - left),
        closeTo(positive / (positive - negative), .0001),
      );
      expect(
        (tester.getCenter(marker).dx - left) / (right - left),
        closeTo(.5, .0001),
      );
      expect(find.textContaining('Recorrido total:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('selecting and dragging never alter a measured position', (
    tester,
  ) async {
    final selections = <XTravelSelection>[];
    await mount(
      tester,
      XTravelView(
        axisReady: true,
        hasCenter: true,
        negativeMm: -20,
        positiveMm: 80,
        positionMm: 10,
        onSelected: selections.add,
      ),
    );
    final before = tester.getCenter(marker);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('x-travel-select-positive')),
        matching: find.text('Tope −'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('x-travel-select-negative')),
        matching: find.text('Tope +'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('x-travel-select-negative')));
    await tester.pump();
    expect(selections, [XTravelSelection.negative]);
    await tester.drag(marker, const Offset(100, 0));
    await tester.pump();
    expect(selections, [XTravelSelection.negative]);
    expect(tester.getCenter(marker), before);
    expect(find.text('X actual: +10.000 mm'), findsOneWidget);
    expect(tester.getCenter(marker).dx, lessThan(x(tester, 'x-travel-zero')));
    expect(find.byType(Slider), findsNothing);
    for (final side in XTravelSelection.values) {
      expect(
        tester
            .getSize(find.byKey(ValueKey('x-travel-select-${side.name}')))
            .height,
        greaterThanOrEqualTo(48),
      );
    }
  });

  testWidgets('reboot hides raw readings while draft anchored center is live', (
    tester,
  ) async {
    await mount(
      tester,
      const XTravelView(
        axisReady: false,
        hasCenter: true,
        negativeMm: -20,
        positiveMm: 80,
        positionMm: 0,
      ),
    );
    expect(marker, findsNothing);
    expect(find.text('Referencia pendiente'), findsOneWidget);
    expect(find.textContaining('X actual:'), findsNothing);
    await mount(
      tester,
      const XTravelView(axisReady: true, hasCenter: true, positionMm: 0),
    );
    expect(marker, findsOneWidget);
    expect(find.text('X actual: 0.000 mm'), findsOneWidget);
    expect(find.text('Sin guardar'), findsNWidgets(2));
    expect(find.textContaining('Vista provisional'), findsOneWidget);
    expect(find.textContaining('Recorrido total:'), findsNothing);
  });

  testWidgets('stale or non-finite readings never create a marker', (
    tester,
  ) async {
    for (final reading in [null, double.nan, double.infinity]) {
      await mount(
        tester,
        XTravelView(axisReady: true, hasCenter: true, positionMm: reading),
      );
      expect(marker, findsNothing);
      expect(find.text('Esperando lectura reciente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'out-of-range value stays truthful and labels fit enlarged text',
    (tester) async {
      await mount(
        tester,
        const XTravelView(
          axisReady: true,
          hasCenter: true,
          negativeMm: -25,
          positiveMm: 75,
          positionMm: 125,
        ),
        scale: 1.3,
      );
      expect(find.text('Fuera del recorrido guardado'), findsOneWidget);
      expect(find.text('X actual: +125.000 mm'), findsOneWidget);
      expect(tester.getCenter(marker).dx, x(tester, 'x-travel-positive-stop'));
      expect(tester.takeException(), isNull);
    },
  );
}
