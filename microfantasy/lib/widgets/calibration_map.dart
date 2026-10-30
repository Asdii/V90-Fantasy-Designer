import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A radial deviation diagram, not an XY reconstruction. Keys and [angles] are
/// degrees, clockwise from the top; values are signed radial offsets in mm.
/// Only [offsets] create measurement points. Two or more samples are joined by
/// piecewise linear offset interpolation, including the last-to-first segment.
class CalibrationMap extends StatelessWidget {
  const CalibrationMap({
    super.key,
    required this.offsets,
    required this.currentAngle,
    required this.angles,
  });

  final Map<double, double> offsets;
  final double currentAngle;
  final List<double> angles;

  @override
  Widget build(BuildContext context) {
    final Map<double, double> normalized = <double, double>{};
    for (final MapEntry<double, double> sample in offsets.entries) {
      if (sample.key.isFinite && sample.value.isFinite) {
        normalized[sample.key % 360] = sample.value;
      }
    }
    final List<double> knownAngles = normalized.keys.toList()..sort();
    final List<_RadialSample> samples = knownAngles
        .map<_RadialSample>(
          (double angle) => _RadialSample(angle, normalized[angle]!),
        )
        .toList(growable: false);
    final List<double> labels = <double>{
      ...angles
          .where((double angle) => angle.isFinite)
          .map<double>((double angle) => angle % 360),
      ...knownAngles,
    }.toList()..sort();
    final double maxOffset = samples.fold<double>(
      0,
      (double largest, _RadialSample sample) =>
          math.max(largest, sample.offset.abs()),
    );
    final double? current = currentAngle.isFinite ? currentAngle % 360 : null;
    final String scale = samples.isEmpty
        ? 'Sin mediciones'
        : maxOffset == 0
        ? 'Base 0 mm · sin desviación'
        : 'Base 0 mm · escala radial ±${_offsetLabel(maxOffset)} mm';

    return Semantics(
      image: true,
      excludeSemantics: true,
      label:
          'Mapa radial de calibración. ${samples.length} mediciones. $scale. '
          '${current == null ? '' : 'Ángulo actual ${_angleLabel(current)}.'}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF6FAFC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(
                  painter: _CalibrationPainter(
                    samples: samples,
                    angles: labels,
                    current: current,
                    maxOffset: maxOffset,
                  ),
                ),
              ),
              Text(
                scale,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF17334B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '+ hacia afuera · − hacia adentro',
                style: TextStyle(fontSize: 11, color: Color(0xFF62798C)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _angleLabel(double angle) =>
    '${angle.toStringAsFixed(angle == angle.roundToDouble() ? 0 : 1)}°';

String _offsetLabel(double offset) => offset < 0.001 && offset > 0
    ? offset.toStringAsExponential(2)
    : offset.toStringAsFixed(3);

class _RadialSample {
  const _RadialSample(this.angle, this.offset);
  final double angle;
  final double offset;
}

class _CalibrationPainter extends CustomPainter {
  const _CalibrationPainter({
    required this.samples,
    required this.angles,
    required this.current,
    required this.maxOffset,
  });

  final List<_RadialSample> samples;
  final List<double> angles;
  final double? current;
  final double maxOffset;

  Offset _polar(Offset center, double radius, double degrees) {
    final double radians = degrees * math.pi / 180;
    return center + Offset(math.sin(radians), -math.cos(radians)) * radius;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double outer = math.max(0, size.shortestSide / 2 - 30);
    if (outer < 12) return;
    final Offset center = size.center(Offset.zero);
    final double base = outer * 0.65;
    final double amplitude = outer * 0.28;
    final Paint basePaint = Paint()
      ..color = const Color(0xFFB7C6D0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, base, basePaint);
    if (samples.isNotEmpty && maxOffset > 0) {
      final Paint extent = Paint()
        ..color = const Color(0xFFE1EBF0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(center, base + amplitude, extent);
      canvas.drawCircle(center, base - amplitude, extent);
    }

    // Angle ticks describe directions only; they are never measurement dots.
    final List<Rect> labelBounds = <Rect>[];
    for (final double angle in angles) {
      canvas.drawLine(
        _polar(center, outer - 3, angle),
        _polar(center, outer + 2, angle),
        Paint()
          ..color = const Color(0xFFB7C6D0)
          ..strokeWidth = 1,
      );
      final TextPainter label = _text(
        _angleLabel(angle),
        10,
        const Color(0xFF62798C),
      );
      final Offset position = _polar(center, outer + 15, angle);
      final Rect bounds = Rect.fromCenter(
        center: position,
        width: label.width,
        height: label.height,
      );
      // Dense angle sets retain all ticks and points without overlapping text.
      if (!labelBounds.any(
        (Rect previous) => previous.overlaps(bounds.inflate(2)),
      )) {
        label.paint(canvas, bounds.topLeft);
        labelBounds.add(bounds);
      }
      label.dispose();
    }

    if (samples.length >= 2) {
      final Path contour = Path();
      for (int i = 0; i < samples.length; i++) {
        final _RadialSample start = samples[i];
        final _RadialSample end = samples[(i + 1) % samples.length];
        final double sweep = (end.angle - start.angle + 360) % 360;
        final int steps = math.max(1, (sweep / 2).ceil());
        for (int step = 0; step <= steps; step++) {
          final double t = step / steps;
          // Interpolate normalized signed offsets, so every radius stays within
          // its two measured endpoints and arithmetic cannot overshoot.
          final double relative = maxOffset == 0
              ? 0
              : (start.offset / maxOffset) * (1 - t) +
                    (end.offset / maxOffset) * t;
          final Offset point = _polar(
            center,
            base + relative * amplitude,
            start.angle + sweep * t,
          );
          if (i == 0 && step == 0) {
            contour.moveTo(point.dx, point.dy);
          } else {
            contour.lineTo(point.dx, point.dy);
          }
        }
      }
      contour.close();
      canvas.drawPath(
        contour,
        Paint()
          ..color = const Color(0xFF1684D6)
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 2,
      );
    }

    final double? selected = current;
    if (selected != null) {
      canvas.drawLine(
        _polar(center, base + amplitude + 3, selected),
        _polar(center, outer + 5, selected),
        Paint()
          ..color = const Color(0xFF28AFC2)
          ..strokeWidth = 3,
      );
    }
    for (final _RadialSample sample in samples) {
      final double radius =
          base + (maxOffset == 0 ? 0 : sample.offset / maxOffset * amplitude);
      final Offset position = _polar(center, radius, sample.angle);
      final double separation = selected == null
          ? 180
          : (sample.angle - selected).abs();
      final bool active = math.min(separation, 360 - separation) < 0.000001;
      canvas.drawCircle(
        position,
        active ? 6 : 4.5,
        Paint()..color = const Color(0xFFF6FAFC),
      );
      canvas.drawCircle(
        position,
        active ? 4.5 : 3,
        Paint()..color = const Color(0xFF1684D6),
      );
      if (active) {
        canvas.drawCircle(
          position,
          8,
          Paint()
            ..color = const Color(0xFF28AFC2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    final TextPainter caption = _text(
      samples.isEmpty ? 'Sin mediciones' : 'Ángulo actual',
      11,
      const Color(0xFF62798C),
    );
    caption.paint(canvas, center - Offset(caption.width / 2, 18));
    caption.dispose();
    final TextPainter angle = _text(
      selected == null ? '—' : _angleLabel(selected),
      20,
      const Color(0xFF17334B),
    );
    angle.paint(canvas, center - Offset(angle.width / 2, -1));
    angle.dispose();
  }

  TextPainter _text(String value, double fontSize, Color color) => TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(fontFamily: 'Roboto', fontSize: fontSize, color: color),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  bool shouldRepaint(covariant _CalibrationPainter oldDelegate) {
    if (current != oldDelegate.current ||
        maxOffset != oldDelegate.maxOffset ||
        samples.length != oldDelegate.samples.length ||
        angles.length != oldDelegate.angles.length) {
      return true;
    }
    for (int i = 0; i < samples.length; i++) {
      if (samples[i].angle != oldDelegate.samples[i].angle ||
          samples[i].offset != oldDelegate.samples[i].offset) {
        return true;
      }
    }
    for (int i = 0; i < angles.length; i++) {
      if (angles[i] != oldDelegate.angles[i]) return true;
    }
    return false;
  }
}
