import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Measured X deviations in mm, indexed by R in degrees clockwise from the top.
/// Each point keeps its reference Y and moves horizontally by its signed X
/// offset. The reference circle locates angles; samples never form a contour.
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final normalized = <double, double>{};
    for (final sample in offsets.entries) {
      if (sample.key.isFinite && sample.value.isFinite) {
        normalized[sample.key % 360] = sample.value;
      }
    }
    final knownAngles = normalized.keys.toList()..sort();
    final samples = [
      for (final angle in knownAngles) _XSample(angle, normalized[angle]!),
    ];
    final current = currentAngle.isFinite ? currentAngle % 360 : null;
    final labels = <double>{
      0,
      ...angles.where((angle) => angle.isFinite).map((angle) => angle % 360),
      ...knownAngles,
      ?current,
    }.toList()..sort();
    final maxOffset = samples.fold<double>(
      0,
      (largest, sample) => math.max(largest, sample.offset.abs()),
    );
    final scale = samples.isEmpty
        ? 'Escala X: pendiente de mediciones'
        : maxOffset == 0
        ? 'Escala X: 0 mm · sin desviación'
        : 'Escala X ampliada: ±${_offsetLabel(maxOffset)} mm';
    const description = 'Desviación X por ángulo · no es una trayectoria XY';

    return Semantics(
      image: true,
      excludeSemantics: true,
      label:
          '$description. 0° arriba. ${samples.length} mediciones. $scale. '
          'X negativo a la izquierda, X positivo a la derecha. '
          '${current == null ? '' : 'Ángulo actual ${_angleLabel(current)}. '}'
          '${samples.map((sample) => '${_angleLabel(sample.angle)}: ${sample.offset > 0 ? '+' : ''}${_offsetLabel(sample.offset)} mm').join('; ')}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(
                  painter: _CalibrationPainter(
                    samples: samples,
                    angles: labels,
                    current: current,
                    maxOffset: maxOffset,
                    colors: colors,
                    textStyle: theme.textTheme.bodySmall ?? const TextStyle(),
                  ),
                ),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 14,
                runSpacing: 4,
                children: [
                  _Legend(
                    color: colors.outline,
                    icon: Icons.radio_button_unchecked,
                    label: 'Referencia',
                  ),
                  _Legend(
                    color: colors.primary,
                    icon: Icons.circle,
                    label: 'Medición X',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('−X ← eje X → +X', style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(
                scale,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.icon, required this.label});
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 11),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

String _angleLabel(double angle) =>
    '${angle.toStringAsFixed(angle == angle.roundToDouble() ? 0 : 1)}°';

String _offsetLabel(double offset) =>
    (offset.abs() < 0.001 && offset != 0) || offset.abs() >= 1000
    ? offset.toStringAsExponential(2)
    : offset.toStringAsFixed(3);

class _XSample {
  const _XSample(this.angle, this.offset);
  final double angle;
  final double offset;
}

class _CalibrationPainter extends CustomPainter {
  const _CalibrationPainter({
    required this.samples,
    required this.angles,
    required this.current,
    required this.maxOffset,
    required this.colors,
    required this.textStyle,
  });

  final List<_XSample> samples;
  final List<double> angles;
  final double? current;
  final double maxOffset;
  final ColorScheme colors;
  final TextStyle textStyle;

  Offset _anchor(Offset center, double radius, double degrees) {
    final radians = degrees * math.pi / 180;
    return center + Offset(math.sin(radians), -math.cos(radians)) * radius;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outer = math.max(0.0, size.shortestSide / 2 - 30);
    if (outer < 12) return;
    final center = size.center(Offset.zero);
    final base = outer * 0.68;
    final amplitude = outer * 0.24;
    final referencePaint = Paint()
      ..color = colors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, base, referencePaint);

    final labelBounds = <Rect>[];
    for (final angle in angles) {
      final anchor = _anchor(center, base, angle);
      // A small vertical tick identifies the ideal anchor for each X reading.
      canvas.drawLine(
        anchor - const Offset(0, 3),
        anchor + const Offset(0, 3),
        referencePaint,
      );
      final active = angle == current;
      final label = _text(
        _angleLabel(angle),
        11,
        active ? colors.primary : colors.onSurfaceVariant,
      );
      final bounds = Rect.fromCenter(
        center: _anchor(center, outer + 14, angle),
        width: label.width,
        height: label.height,
      );
      // Sorted labels give 0° priority, including in a dense set of samples.
      if (!labelBounds.any(
        (previous) => previous.overlaps(bounds.inflate(2)),
      )) {
        label.paint(canvas, bounds.topLeft);
        labelBounds.add(bounds);
      }
      label.dispose();
    }

    final selected = current;
    if (selected != null &&
        !samples.any((sample) => sample.angle == selected)) {
      canvas.drawCircle(
        _anchor(center, base, selected),
        7,
        Paint()
          ..color = colors.primary.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    for (final sample in samples) {
      final anchor = _anchor(center, base, sample.angle);
      final dx = maxOffset == 0 ? 0.0 : sample.offset / maxOffset * amplitude;
      // Y is deliberately unchanged at every R, even at 0° and 180°.
      final position = Offset(anchor.dx + dx, anchor.dy);
      final active = sample.angle == selected;
      canvas.drawLine(
        anchor,
        position,
        Paint()
          ..color = colors.onSurfaceVariant.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        position,
        active ? 6 : 5,
        Paint()..color = colors.surface,
      );
      canvas.drawCircle(
        position,
        active ? 4.5 : 3.5,
        Paint()..color = colors.primary,
      );
      if (active) {
        canvas.drawCircle(
          position,
          8,
          Paint()
            ..color = colors.primary.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    final caption = _text('R actual', 11, colors.onSurfaceVariant);
    caption.paint(canvas, center - Offset(caption.width / 2, 23));
    caption.dispose();
    final angle = _text(
      selected == null ? '—' : _angleLabel(selected),
      24,
      colors.onSurface,
    );
    angle.paint(canvas, center - Offset(angle.width / 2, 5));
    angle.dispose();
  }

  TextPainter _text(String value, double fontSize, Color color) => TextPainter(
    text: TextSpan(
      text: value,
      style: textStyle.copyWith(fontSize: fontSize, color: color),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  bool shouldRepaint(covariant _CalibrationPainter oldDelegate) {
    if (current != oldDelegate.current ||
        maxOffset != oldDelegate.maxOffset ||
        colors != oldDelegate.colors ||
        textStyle != oldDelegate.textStyle ||
        samples.length != oldDelegate.samples.length ||
        angles.length != oldDelegate.angles.length) {
      return true;
    }
    for (var i = 0; i < samples.length; i++) {
      if (samples[i].angle != oldDelegate.samples[i].angle ||
          samples[i].offset != oldDelegate.samples[i].offset) {
        return true;
      }
    }
    for (var i = 0; i < angles.length; i++) {
      if (angles[i] != oldDelegate.angles[i]) return true;
    }
    return false;
  }
}
