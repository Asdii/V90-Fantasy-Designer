import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/widgets/calibration_map.dart';

void main() {
  final theme = ThemeData.light();

  Future<CustomPainter> drawMap(
    WidgetTester tester,
    Map<double, double> offsets, {
    List<double> angles = const [0, 30, 90, 180, 270],
    double current = 0,
    ThemeData? appearance,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appearance ?? theme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: CalibrationMap(
                offsets: offsets,
                currentAngle: current,
                angles: angles,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(CalibrationMap),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter!;
  }

  testWidgets('samples only move in X and are never joined into a contour', (
    tester,
  ) async {
    final painter = await drawMap(tester, {
      0: 2,
      30: -1,
      90: 1,
      180: -2,
      270: 0,
    });
    final canvas = _RecordingCanvas();
    painter.paint(canvas, const Size(320, 320));
    final reference = canvas.circles.first;
    final dots = canvas.circles
        .where(
          (circle) =>
              circle.color.toARGB32() == theme.colorScheme.primary.toARGB32() &&
              circle.style == PaintingStyle.fill,
        )
        .toList();
    final connectors = canvas.lines
        .where(
          (line) =>
              line.color.toARGB32() != theme.colorScheme.outline.toARGB32(),
        )
        .toList();
    expect(dots, hasLength(5));
    expect(connectors, hasLength(5));
    expect(canvas.paths, 0);
    final fullScale = connectors.first.end.dx - connectors.first.start.dx;
    final relativeOffsets = [1, -.5, .5, -1, 0];
    for (var i = 0; i < connectors.length; i++) {
      final line = connectors[i];
      expect(line.end.dy, line.start.dy);
      expect(dots[i].center, line.end);
      expect(
        (line.start - reference.center).distance,
        closeTo(reference.radius, 1e-9),
      );
      expect(
        line.end.dx - line.start.dx,
        closeTo(fullScale * relativeOffsets[i], 1e-9),
      );
    }
    // The zero-degree reference is at the top, never the bottom or right.
    expect(connectors.first.start.dx, reference.center.dx);
    expect(connectors.first.start.dy, reference.center.dy - reference.radius);
    expect(
      find.text('Desviación X por ángulo · no es una trayectoria XY'),
      findsOneWidget,
    );
    expect(find.text('−X ← eje X → +X'), findsOneWidget);
    expect(find.text('Escala X ampliada: ±2.000 mm'), findsOneWidget);
  });

  testWidgets('empty, zero and invalid data never fabricate measurements', (
    tester,
  ) async {
    for (final offsets in <Map<double, double>>[
      {},
      {360: 0, 90: double.nan, double.infinity: 2},
    ]) {
      final painter = await drawMap(
        tester,
        offsets,
        current: double.nan,
        angles: [90, double.nan],
      );
      final canvas = _RecordingCanvas();
      painter.paint(canvas, const Size(320, 320));
      final dots = canvas.circles.where(
        (circle) =>
            circle.style == PaintingStyle.fill &&
            circle.color.toARGB32() == theme.colorScheme.primary.toARGB32(),
      );
      expect(dots.length, offsets.isEmpty ? 0 : 1);
      expect(canvas.paths, 0);
      if (offsets.isNotEmpty) {
        final reference = canvas.circles.first;
        expect(
          dots.single.center,
          reference.center - Offset(0, reference.radius),
        );
        expect(find.text('Escala X: 0 mm · sin desviación'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('map repaints when the theme changes', (tester) async {
    final original = await drawMap(tester, {0: 0, 30: .2});
    final changed = await drawMap(tester, {
      0: 0,
      30: .2,
    }, appearance: ThemeData(colorSchemeSeed: Colors.purple));
    expect(changed.shouldRepaint(original), isTrue);
  });
}

class _RecordingCanvas implements Canvas {
  final circles =
      <({Offset center, double radius, Color color, PaintingStyle style})>[];
  final lines = <({Offset start, Offset end, Color color})>[];
  int paths = 0;

  @override
  void drawCircle(Offset center, double radius, Paint paint) {
    circles.add((
      center: center,
      radius: radius,
      color: paint.color,
      style: paint.style,
    ));
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    lines.add((start: p1, end: p2, color: paint.color));
  }

  @override
  void drawPath(Path path, Paint paint) => paths++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
