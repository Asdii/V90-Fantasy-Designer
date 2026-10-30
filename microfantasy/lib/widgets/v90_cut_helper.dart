import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/cut_helper_data.dart';

/// Mirrors V90's SVG scene in the shared facet-local frame, including its wheel.
class V90CutHelper extends StatelessWidget {
  const V90CutHelper({
    super.key,
    required this.data,
    required this.stepIndex,
    required this.angleDeg,
    required this.direction,
    required this.zeroView,
  });
  final CutHelperData data;
  final int stepIndex;
  final double angleDeg;
  final String direction;
  final bool zeroView;
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label:
        'Cut Helper V90. Faceta ${data.referenceFacetId}. Paso ${stepIndex + 1}. ${direction == 'vertical' ? 'Vertical' : 'Horizontal'}.',
    child: AspectRatio(
      aspectRatio: 1,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: zeroView ? 0.0 : angleDeg),
        duration: const Duration(milliseconds: 420),
        curve: const Cubic(.22, .8, .3, 1),
        builder: (context, rotation, _) => TweenAnimationBuilder<double>(
          tween: Tween(end: direction == 'vertical' ? -90.0 : 0.0),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          builder: (context, patternRotation, _) => CustomPaint(
            painter: _HelperPainter(data, stepIndex, rotation, patternRotation),
          ),
        ),
      ),
    ),
  );
}

class _HelperPainter extends CustomPainter {
  _HelperPainter(
    this.data,
    this.stepIndex,
    this.rotation,
    this.patternRotation,
  );
  final CutHelperData data;
  final int stepIndex;
  final double rotation, patternRotation;
  Offset point(HelperPoint p) => Offset(p.u, -p.v);
  Paint stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / (2 * data.extent);
    if (scale <= 0) return;
    final r = data.wheelRadius, hair = data.hairline;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xfff7f9fb),
    );
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.save();
    canvas.rotate(rotation * math.pi / 180);
    canvas.drawCircle(Offset.zero, r, Paint()..color = const Color(0xff262b30));
    canvas.drawCircle(
      Offset.zero,
      r,
      stroke(const Color(0xff11161a), 2 / scale),
    );
    for (var degree = 0; degree < 360; degree += 5) {
      final a = degree * math.pi / 180;
      final major = degree % 30 == 0;
      final inner =
          r *
          (1 -
              (major
                  ? .09
                  : degree % 10 == 0
                  ? .06
                  : .035));
      final axis = Offset(math.sin(a), math.cos(a));
      canvas.drawLine(
        axis * inner,
        axis * r,
        stroke(
          Color(major ? 0xfff2f4f6 : 0xffb9c0c6),
          (major ? 1.7 : 1) / scale,
        ),
      );
      if (major) {
        final text = TextPainter(
          text: TextSpan(
            text: '$degree°',
            style: TextStyle(
              color: const Color(0xfff3f5f7),
              fontSize: r * .075,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(
          canvas,
          axis * (r * .84) - Offset(text.width / 2, text.height / 2),
        );
      }
    }
    _axis(canvas, true, scale);
    _axis(canvas, false, scale);
    final facet = Path()..addPolygon(data.boundary.map(point).toList(), true);
    canvas.drawPath(
      facet,
      Paint()..color = const Color(0xffdce3e8).withValues(alpha: .92),
    );
    canvas.drawPath(facet, stroke(const Color(0xff38444e), 1.5 / scale));
    canvas.save();
    canvas.rotate(patternRotation * math.pi / 180);
    for (var i = 0; i < stepIndex; i++) {
      for (final segment in data.steps[i].visibleSegments) {
        canvas.drawLine(
          point(segment.start),
          point(segment.end),
          stroke(const Color(0xff557f93).withValues(alpha: .7), hair * 1.25),
        );
        _arrow(canvas, segment, hair * 5, false);
      }
    }
    final active = data.steps[stepIndex];
    for (final segment in active.visibleSegments) {
      canvas.drawLine(
        point(segment.start),
        point(segment.end),
        stroke(
          const Color(0xff19bfe8).withValues(alpha: .58),
          math.max(active.grooveWidthMm, hair * 3),
        ),
      );
      canvas.drawLine(
        point(segment.start),
        point(segment.end),
        stroke(const Color(0xff101820), hair),
      );
      _arrow(canvas, segment, hair * 8, true);
    }
    canvas.restore();
    canvas.drawCircle(
      Offset.zero,
      hair * 2.4,
      Paint()..color = const Color(0xfff7f9fb),
    );
    canvas.drawCircle(
      Offset.zero,
      hair * 2.4,
      stroke(const Color(0xff202a33), 1.4 / scale),
    );
    canvas.restore();
    final marker = Path()
      ..moveTo(-r * .035, r * 1.08)
      ..lineTo(0, r * .99)
      ..lineTo(r * .035, r * 1.08)
      ..close();
    canvas.drawPath(marker, Paint()..color = const Color(0xffd6a928));
    canvas.drawPath(marker, stroke(const Color(0xff11161a), 1 / scale));
    canvas.restore();
  }

  void _axis(Canvas canvas, bool horizontal, double scale) {
    final pen = stroke(
      Color(horizontal ? 0xffb94848 : 0xff32805a).withValues(alpha: .42),
      1 / scale,
    );
    final dash = 5 / scale;
    for (var v = -data.extent; v < data.extent; v += dash * 2) {
      final end = math.min(v + dash, data.extent);
      canvas.drawLine(
        horizontal ? Offset(v, 0) : Offset(0, v),
        horizontal ? Offset(end, 0) : Offset(0, end),
        pen,
      );
    }
  }

  void _arrow(Canvas canvas, HelperSegment segment, double size, bool active) {
    final a = point(segment.start), b = point(segment.end), vector = b - a;
    if (vector.distance <= 1e-12) return;
    final box = active ? 7.0 : 6.0, refX = active ? 5.5 : 5.0;
    canvas.save();
    canvas.translate(b.dx, b.dy);
    canvas.rotate(math.atan2(vector.dy, vector.dx));
    canvas.scale(size / box);
    final path = Path()
      ..moveTo(-refX, -box / 2)
      ..lineTo(box - refX, 0)
      ..lineTo(-refX, box / 2)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = Color(active ? 0xff101820 : 0xff347b98),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HelperPainter old) =>
      old.data != data ||
      old.stepIndex != stepIndex ||
      old.rotation != rotation ||
      old.patternRotation != patternRotation;
}
