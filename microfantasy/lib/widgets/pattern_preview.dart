import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Normalized polylines, with (0, 0) at the top left. The caller supplies any
/// fallback geometry; an empty list deliberately shows an empty preview.
class PatternPreview extends StatelessWidget {
  const PatternPreview({
    super.key,
    required this.lines,
    required this.activeIndex,
    this.activeIndices,
  });

  final List<List<Offset>> lines;

  /// Zero based; used for highlighting when [activeIndices] is null, and always
  /// as the boundary before which inactive strokes are shown as previous.
  final int activeIndex;

  /// Optional zero-based selection for steps containing multiple strokes.
  /// Overrides [activeIndex] for highlighting, including when empty. Invalid
  /// indices are ignored; null preserves the original single-stroke behavior.
  final Set<int>? activeIndices;

  @override
  Widget build(BuildContext context) {
    final Set<int> selected = (activeIndices ?? <int>{activeIndex})
        .where((int index) => index >= 0 && index < lines.length)
        .toSet();
    final List<int> sortedSelection = selected.toList()..sort();
    final String activeDescription = selected.isEmpty
        ? 'Sin trazo activo.'
        : selected.length == 1
        ? 'Trazo activo ${sortedSelection.single + 1}.'
        : 'Trazos activos ${sortedSelection.map<String>((int index) => '${index + 1}').join(', ')}.';
    return Semantics(
      image: true,
      label: lines.isEmpty
          ? 'Vista previa sin trazos'
          : 'Vista previa: ${lines.length} trazos. $activeDescription',
      child: AspectRatio(
        aspectRatio: 1.25,
        child: CustomPaint(
          painter: _PatternPainter(
            lines: lines,
            activeIndex: activeIndex,
            activeIndices: selected,
          ),
        ),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required List<List<Offset>> lines,
    required this.activeIndex,
    required Set<int> activeIndices,
  }) : lines = List<List<Offset>>.unmodifiable(
         lines.map<List<Offset>>(
           (List<Offset> line) => List<Offset>.unmodifiable(line),
         ),
       ),
       activeIndices = Set<int>.unmodifiable(activeIndices);

  final List<List<Offset>> lines;
  final int activeIndex;
  final Set<int> activeIndices;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final RRect background = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    );
    canvas.drawRRect(background, Paint()..color = const Color(0xFFF6FAFC));
    final double inset = math.min(20, size.shortestSide / 8);
    final double side = math.max(0, size.shortestSide - inset * 2);
    final Rect viewport = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );
    final Paint grid = Paint()
      ..color = const Color(0xFFE3EDF2)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final double fraction = i / 4;
      final double x = viewport.left + side * fraction;
      final double y = viewport.top + side * fraction;
      canvas.drawLine(
        Offset(x, viewport.top),
        Offset(x, viewport.bottom),
        grid,
      );
      canvas.drawLine(
        Offset(viewport.left, y),
        Offset(viewport.right, y),
        grid,
      );
    }

    canvas.save();
    canvas.clipRRect(background);
    // Paint all active strokes last so overlapping inactive strokes cannot hide them.
    for (int i = 0; i < lines.length; i++) {
      if (activeIndices.contains(i)) continue;
      _stroke(
        canvas,
        viewport,
        lines[i],
        i < activeIndex ? const Color(0xFFA9BAC6) : const Color(0xFF91D1DE),
        1.8,
      );
    }
    for (int i = 0; i < lines.length; i++) {
      if (!activeIndices.contains(i)) continue;
      _stroke(canvas, viewport, lines[i], const Color(0xFF1684D6), 3.2);
    }
    canvas.restore();
  }

  void _stroke(
    Canvas canvas,
    Rect viewport,
    List<Offset> points,
    Color color,
    double width,
  ) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width;
    final Path path = Path();
    bool connected = false;
    for (final Offset point in points) {
      if (!point.dx.isFinite || !point.dy.isFinite) {
        connected = false;
        continue;
      }
      final Offset mapped = Offset(
        viewport.left + point.dx.clamp(0.0, 1.0).toDouble() * viewport.width,
        viewport.top + point.dy.clamp(0.0, 1.0).toDouble() * viewport.height,
      );
      if (connected) {
        path.lineTo(mapped.dx, mapped.dy);
      } else {
        path.moveTo(mapped.dx, mapped.dy);
        canvas.drawCircle(mapped, width / 2, Paint()..color = color);
      }
      connected = true;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    if (activeIndex != oldDelegate.activeIndex ||
        activeIndices.length != oldDelegate.activeIndices.length ||
        !activeIndices.containsAll(oldDelegate.activeIndices) ||
        lines.length != oldDelegate.lines.length) {
      return true;
    }
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].length != oldDelegate.lines[i].length) return true;
      for (int j = 0; j < lines[i].length; j++) {
        if (lines[i][j] != oldDelegate.lines[i][j]) return true;
      }
    }
    return false;
  }
}
