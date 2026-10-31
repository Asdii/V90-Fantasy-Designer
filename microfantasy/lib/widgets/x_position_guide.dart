import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A display-only guide. All inputs and tolerance comparisons remain in mm.
/// [centimeters] changes labels only. [smoothing] accepts off, light or medium
/// (unknown names use off); it never filters or compensates a measurement.
/// Even off retains short frame interpolation; readings and status stay raw.
class XPositionGuide extends StatefulWidget {
  const XPositionGuide({
    super.key,
    required this.actualMm,
    required this.targetMm,
    required this.toleranceMm,
    required this.smoothing,
    required this.centimeters,
  });

  final double? actualMm;
  final double targetMm;
  final double toleranceMm;
  final String smoothing;
  final bool centimeters;

  @override
  State<XPositionGuide> createState() => _XPositionGuideState();
}

class _XPositionGuideState extends State<XPositionGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _markerController;
  // The main ruler always spans 25 mm, centered on the corrected target.
  static const double _mainRangeMm = 12.5;
  double? _actualFrom;
  double? _actualTo;
  bool _showPrecision = false;

  static double? _finite(double? value) =>
      value != null && value.isFinite ? value : null;

  static bool _validTolerance(double value) => value.isFinite && value >= 0;

  static Duration _duration(String smoothing) {
    return switch (smoothing.trim().toLowerCase()) {
      'light' => const Duration(milliseconds: 140),
      'medium' => const Duration(milliseconds: 220),
      _ => const Duration(milliseconds: 90),
    };
  }

  double? get _visualActual {
    final double? start = _actualFrom;
    final double? end = _actualTo;
    if (start == null || end == null) return end;
    final double progress = Curves.easeOutCubic.transform(
      _markerController.value,
    );
    return start * (1 - progress) + end * progress;
  }

  double get _precisionRange {
    final double range = _validTolerance(widget.toleranceMm)
        ? math.max(0.05, widget.toleranceMm * 2)
        : 0.05;
    return range.isFinite ? range : double.maxFinite;
  }

  void _updatePrecision() {
    final double? actual = _finite(widget.actualMm);
    // A small exit margin avoids flicker around the inset's visibility threshold.
    final double threshold = _precisionRange * (_showPrecision ? 1.25 : 1);
    _showPrecision =
        actual != null &&
        widget.targetMm.isFinite &&
        _validTolerance(widget.toleranceMm) &&
        (actual - widget.targetMm).abs() <= threshold;
  }

  @override
  void initState() {
    super.initState();
    _actualFrom = _actualTo = _finite(widget.actualMm);
    _markerController = AnimationController(vsync: this, value: 1);
    _updatePrecision();
  }

  @override
  void didUpdateWidget(covariant XPositionGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actualMm == widget.actualMm &&
        oldWidget.targetMm == widget.targetMm &&
        oldWidget.toleranceMm == widget.toleranceMm &&
        oldWidget.smoothing == widget.smoothing) {
      return;
    }

    final double? previous = _visualActual;
    final double? next = _finite(widget.actualMm);
    if (oldWidget.targetMm != widget.targetMm ||
        oldWidget.toleranceMm != widget.toleranceMm) {
      _showPrecision = false;
    }
    // Retarget from the currently displayed position, including tolerance
    // crossings. Only the graphic eases: actual labels/success never lag.
    final Duration smoothingDuration = _duration(widget.smoothing);
    _actualFrom = previous != null && next != null ? previous : next;
    _actualTo = next;
    _markerController.stop();
    if (_actualFrom == _actualTo) {
      _markerController.value = 1;
    } else {
      _markerController.duration = smoothingDuration;
      _markerController.forward(from: 0);
    }
    _updatePrecision();
  }

  @override
  void dispose() {
    _markerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    // Green has a measurement meaning and stays independent of the accent hue.
    final Color successColor = colors.brightness == Brightness.dark
        ? const Color(0xFF7CD9A6)
        : const Color(0xFF227A50);
    final double? actual = _finite(widget.actualMm);
    final bool validTarget = widget.targetMm.isFinite;
    final bool validTolerance = _validTolerance(widget.toleranceMm);
    final bool ready = actual != null && validTarget && validTolerance;
    final double? error = ready ? actual - widget.targetMm : null;
    final bool arrived = error != null && error.abs() <= widget.toleranceMm;
    final String status = actual == null
        ? 'Sin conexión'
        : !validTarget || !validTolerance
        ? 'Objetivo o tolerancia no válido'
        : arrived
        ? 'En tolerancia'
        : error! < 0
        ? 'Mover hacia +X'
        : 'Mover hacia −X';
    final String actualLabel = actual == null
        ? '—'
        : _length(actual, widget.centimeters);
    final String targetLabel = validTarget
        ? _length(widget.targetMm, widget.centimeters)
        : '—';
    final Color statusColor = arrived ? successColor : colors.onSurfaceVariant;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'Posición X. Actual $actualLabel. Objetivo $targetLabel. $status.',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _reading(
                      theme,
                      'Actual',
                      actualLabel,
                      TextAlign.left,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _reading(
                      theme,
                      'Objetivo',
                      targetLabel,
                      TextAlign.right,
                    ),
                  ),
                ],
              ),
              AnimatedBuilder(
                animation: _markerController,
                builder: (BuildContext context, Widget? child) {
                  const range = _mainRangeMm;
                  return Column(
                    children: <Widget>[
                      // Reserve both layers: the main ruler never moves when
                      // the detail lens appears. The funnel points to its exact
                      // represented interval on the main ruler.
                      SizedBox(
                        height: 180,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: IgnorePointer(
                                child: AnimatedOpacity(
                                  opacity: _showPrecision ? 1 : 0,
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeInOut,
                                  child: CustomPaint(
                                    key: const ValueKey('x-zoom-connector'),
                                    painter: _ZoomConnectorPainter(
                                      range: range,
                                      detailRange: _precisionRange,
                                      colors: colors,
                                    ),
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: AnimatedSlide(
                                        offset: Offset(
                                          0,
                                          _showPrecision ? 0 : .08,
                                        ),
                                        duration: const Duration(
                                          milliseconds: 280,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        child: Container(
                                          height: 72,
                                          margin: const EdgeInsets.fromLTRB(
                                            16,
                                            8,
                                            16,
                                            0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.surfaceContainerLow,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: colors.outlineVariant,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              const SizedBox(height: 5),
                                              Text(
                                                'Detalle · ±${_length(_precisionRange, widget.centimeters, compact: true)}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: colors
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                              Expanded(
                                                child: CustomPaint(
                                                  key: const ValueKey(
                                                    'x-precision-bar',
                                                  ),
                                                  size: const Size(
                                                    double.infinity,
                                                    double.infinity,
                                                  ),
                                                  painter: _PositionPainter(
                                                    actual: ready
                                                        ? _visualActual
                                                        : null,
                                                    target: validTarget
                                                        ? widget.targetMm
                                                        : 0,
                                                    tolerance: validTolerance
                                                        ? widget.toleranceMm
                                                        : 0,
                                                    range: _precisionRange,
                                                    centimeters:
                                                        widget.centimeters,
                                                    colors: colors,
                                                    successColor: successColor,
                                                    precision: true,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 92,
                              height: 88,
                              child: CustomPaint(
                                key: const ValueKey('x-position-bar'),
                                painter: _PositionPainter(
                                  actual: ready ? _visualActual : null,
                                  target: validTarget ? widget.targetMm : 0,
                                  tolerance: validTolerance
                                      ? widget.toleranceMm
                                      : 0,
                                  range: range,
                                  centimeters: widget.centimeters,
                                  colors: colors,
                                  successColor: successColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 16,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Rango fijo ±${_length(range, widget.centimeters, compact: true)}'
                            ' · tolerancia ${validTolerance ? '±${_length(widget.toleranceMm, widget.centimeters, compact: true)}' : '—'}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    arrived
                        ? Icons.check_circle_outline
                        : actual == null
                        ? Icons.sensors_off
                        : Icons.swap_horiz,
                    color: statusColor,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reading(
    ThemeData theme,
    String label,
    String value,
    TextAlign alignment,
  ) {
    return Column(
      crossAxisAlignment: alignment == TextAlign.left
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment == TextAlign.left
              ? Alignment.centerLeft
              : Alignment.centerRight,
          child: Text(
            value,
            textAlign: alignment,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

String _length(double millimeters, bool centimeters, {bool compact = false}) {
  final double value = centimeters ? millimeters / 10 : millimeters;
  String number = value.toStringAsFixed(centimeters ? 4 : 3);
  if (compact && number.contains('.')) {
    number = number
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return '$number ${centimeters ? 'cm' : 'mm'}';
}

class _PositionPainter extends CustomPainter {
  const _PositionPainter({
    required this.actual,
    required this.target,
    required this.tolerance,
    required this.range,
    required this.centimeters,
    required this.colors,
    required this.successColor,
    this.precision = false,
  });

  final double? actual;
  final double target;
  final double tolerance;
  final double range;
  final bool centimeters;
  final ColorScheme colors;
  final Color successColor;
  final bool precision;

  String tickLabel(double delta) => _length(target + delta, centimeters);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 32 || size.height < (precision ? 36 : 70)) return;
    final double inset = math.min(36, size.width * 0.12);
    final double left = inset;
    final double right = size.width - inset;
    final double center = size.width / 2;
    final double halfWidth = (right - left) / 2;
    final double y = precision ? 17 : 34;
    final double thickness = precision ? 3 : 5;
    final Rect bar = Rect.fromLTRB(left, y - thickness, right, y + thickness);
    final RRect roundedBar = RRect.fromRectAndRadius(
      bar,
      const Radius.circular(5),
    );
    canvas.drawRRect(
      roundedBar,
      Paint()
        ..color = colors.brightness == Brightness.dark
            ? const Color(0xff9da9b3)
            : const Color(0xffd9dee2),
    );

    if (tolerance > 0) {
      // Preserve the true tolerance ratio, clipped to the fixed visible range.
      final double bandHalfWidth =
          halfWidth * (tolerance / range).clamp(0.0, 1.0);
      final Rect band = Rect.fromLTRB(
        center - bandHalfWidth,
        bar.top,
        center + bandHalfWidth,
        bar.bottom,
      );
      canvas.save();
      canvas.clipRRect(roundedBar);
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            colors: <Color>[
              successColor.withValues(alpha: 0),
              successColor.withValues(alpha: 0.35),
              colors.brightness == Brightness.dark
                  ? successColor
                  : const Color(0xFF54B980),
              successColor.withValues(alpha: 0.35),
              successColor.withValues(alpha: 0),
            ],
            stops: const <double>[0, 0.25, 0.5, 0.75, 1],
          ).createShader(band),
      );
      canvas.restore();
    }

    canvas.drawLine(
      Offset(center, y - 13),
      Offset(center, y + 13),
      Paint()
        ..color = successColor
        ..strokeWidth = 1.5,
    );
    for (int tick = -10; tick <= 10; tick++) {
      if (tick == 0) continue;
      final x = center + tick / 10 * halfWidth;
      canvas.drawLine(
        Offset(x, y + 9),
        Offset(x, y + (tick % 5 == 0 ? 15 : 12)),
        Paint()
          ..color = colors.outlineVariant
          ..strokeWidth = 1,
      );
    }
    for (int i = -2; i <= 2; i++) {
      // Three absolute labels leave space for thousandths on phone screens.
      if (i.abs() == 1) continue;
      final double fraction = i / 2;
      final double x = center + fraction * halfWidth;
      canvas.drawLine(
        Offset(x, y + (precision ? 8 : 16)),
        Offset(x, y + (precision ? 11 : 21)),
        Paint()
          ..color = colors.outlineVariant
          ..strokeWidth = 1,
      );
      final double delta = fraction * range;
      final TextPainter label = TextPainter(
        text: TextSpan(
          text: tickLabel(delta),
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: i == 0 ? 11 : 10,
            fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w400,
            color: i == 0 ? colors.onSurface : colors.onSurfaceVariant,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: math.max(1, halfWidth));
      label.paint(
        canvas,
        Offset(
          (x - label.width / 2).clamp(0, size.width - label.width).toDouble(),
          y + (precision ? 12 : 27),
        ),
      );
      label.dispose();
    }

    final double? live = actual;
    if (live == null) return;
    final double relative = (live - target) / range;
    final double x = center + relative.clamp(-1.0, 1.0).toDouble() * halfWidth;
    final Paint marker = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5;
    // A pale keyline keeps the black sensor marker legible in the dark theme.
    canvas.drawLine(
      Offset(x, y - 14),
      Offset(x, y + 13),
      Paint()
        ..color = colors.surface
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(Offset(x, y - 14), Offset(x, y + 13), marker);
    final Path triangle = Path();
    if (relative.abs() > 1) {
      final double direction = relative < 0 ? -1 : 1;
      triangle.moveTo(x + direction * 7, y);
      triangle.lineTo(x - direction * 1, y - 5);
      triangle.lineTo(x - direction * 1, y + 5);
    } else {
      triangle.moveTo(x, y - 13);
      triangle.lineTo(x - 5, y - 20);
      triangle.lineTo(x + 5, y - 20);
    }
    triangle.close();
    canvas.drawPath(triangle, marker);
  }

  @override
  bool shouldRepaint(covariant _PositionPainter oldDelegate) =>
      actual != oldDelegate.actual ||
      target != oldDelegate.target ||
      tolerance != oldDelegate.tolerance ||
      range != oldDelegate.range ||
      centimeters != oldDelegate.centimeters ||
      colors != oldDelegate.colors ||
      successColor != oldDelegate.successColor ||
      precision != oldDelegate.precision;
}

/// A magnifier funnel: its narrow end is the actual detail interval on the
/// main scale, not a decorative point unrelated to the ruler's current zoom.
class _ZoomConnectorPainter extends CustomPainter {
  const _ZoomConnectorPainter({
    required this.range,
    required this.detailRange,
    required this.colors,
  });
  final double range, detailRange;
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width / 2;
    final halfTrack = center - math.min(36, size.width * .12);
    final focus = halfTrack * (detailRange / range).clamp(0.0, 1.0);
    final lensHalf = math.max(0.0, center - 30);
    final funnel = Path()
      ..moveTo(center - lensHalf, 78)
      ..cubicTo(center - lensHalf, 91, center - focus, 99, center - focus, 112)
      ..lineTo(center - focus, 123)
      ..lineTo(center + focus, 123)
      ..lineTo(center + focus, 112)
      ..cubicTo(
        center + focus,
        99,
        center + lensHalf,
        91,
        center + lensHalf,
        78,
      );
    canvas.drawPath(
      funnel,
      Paint()..color = colors.primary.withValues(alpha: .035),
    );
    canvas.drawPath(
      funnel,
      Paint()
        ..color = colors.primary.withValues(alpha: .35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _ZoomConnectorPainter oldDelegate) =>
      range != oldDelegate.range ||
      detailRange != oldDelegate.detailRange ||
      colors != oldDelegate.colors;
}
