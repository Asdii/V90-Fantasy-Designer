import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A display-only guide. All inputs and tolerance comparisons remain in mm.
/// [centimeters] changes labels only. [smoothing] accepts off, light or medium
/// (unknown names use off); it never filters or compensates a measurement.
/// Scale changes animate even when marker smoothing is off.
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
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final AnimationController _markerController;
  late final Listenable _animations;
  double _scaleBand = 5;
  late double _rangeFrom;
  late double _rangeTo;
  double? _actualFrom;
  double? _actualTo;
  bool _showPrecision = false;

  static double? _finite(double? value) =>
      value != null && value.isFinite ? value : null;

  static bool _validTolerance(double value) => value.isFinite && value >= 0;

  static Duration _duration(String smoothing) {
    return switch (smoothing.trim().toLowerCase()) {
      'light' => const Duration(milliseconds: 100),
      'medium' => const Duration(milliseconds: 200),
      _ => Duration.zero,
    };
  }

  double _nextRange() {
    final double? actual = _finite(widget.actualMm);
    final double distance = actual != null && widget.targetMm.isFinite
        ? (actual - widget.targetMm).abs()
        : double.infinity;
    // Enter at 0.15 / 0.8 mm, leave at 0.18 / 0.9 mm. Noisy readings near
    // either entry threshold must not keep reversing an unfinished zoom.
    final double closeLimit = _scaleBand == 0.2 ? 0.18 : 0.15;
    final double middleLimit = _scaleBand <= 1 ? 0.9 : 0.8;
    _scaleBand = distance <= closeLimit
        ? 0.2
        : distance <= middleLimit
        ? 1
        : 5;
    final double floor = _validTolerance(widget.toleranceMm)
        ? widget.toleranceMm * 8
        : 0;
    return math.max(_scaleBand, floor.isFinite ? floor : double.maxFinite);
  }

  double get _visualRange {
    final double progress = Curves.easeInOutCubic.transform(
      _scaleController.value,
    );
    return _rangeFrom * (1 - progress) + _rangeTo * progress;
  }

  double? get _visualActual {
    final double? start = _actualFrom;
    final double? end = _actualTo;
    if (start == null || end == null) return end;
    final double progress = Curves.easeOutCubic.transform(
      _markerController.value,
    );
    final double visual = start * (1 - progress) + end * progress;
    // Even rounding at a boundary must not place an outside reading in the band.
    return _zone(visual) == _zone(end) ? visual : end;
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

  int _zone(double value) {
    final double error = value - widget.targetMm;
    if (error.abs() <= widget.toleranceMm) return 0;
    return error < 0 ? -1 : 1;
  }

  @override
  void initState() {
    super.initState();
    _rangeFrom = _rangeTo = _nextRange();
    _actualFrom = _actualTo = _finite(widget.actualMm);
    _scaleController = AnimationController(
      vsync: this,
      value: 1,
      duration: const Duration(milliseconds: 240),
    );
    _markerController = AnimationController(vsync: this, value: 1);
    _animations = Listenable.merge([_scaleController, _markerController]);
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
      _scaleBand = 5;
      _showPrecision = false;
    }
    final double nextRange = _nextRange();
    // Telemetry can retarget the marker without restarting an ongoing zoom.
    // Only a new scale destination starts a new scale transition.
    if (nextRange != _rangeTo) {
      _rangeFrom = _visualRange;
      _rangeTo = nextRange;
      _scaleController.forward(from: 0);
    }
    // Never animate across a tolerance boundary: crossing the band must
    // reflect the raw sensor, including opposite-side jumps and disconnection.
    final bool sameZone =
        previous != null &&
        next != null &&
        widget.targetMm.isFinite &&
        _validTolerance(widget.toleranceMm) &&
        oldWidget.targetMm == widget.targetMm &&
        oldWidget.toleranceMm == widget.toleranceMm &&
        _zone(previous) == _zone(next);
    final Duration smoothingDuration = _duration(widget.smoothing);
    _actualFrom = sameZone && smoothingDuration != Duration.zero
        ? previous
        : next;
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
    _scaleController.dispose();
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
          padding: const EdgeInsets.all(16),
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
                animation: _animations,
                builder: (BuildContext context, Widget? child) {
                  // A tolerance increase must never briefly exaggerate the
                  // tolerance width while the scale is catching up.
                  final double floor = validTolerance
                      ? widget.toleranceMm * 8
                      : 0;
                  final double range = math.max(
                    _visualRange,
                    floor.isFinite ? floor : double.maxFinite,
                  );
                  return Column(
                    children: <Widget>[
                      // Keep this slot even when hidden so the main bar never
                      // moves as a measurement enters or leaves the detail view.
                      SizedBox(
                        height:
                            92 +
                            math.max(
                              0,
                              MediaQuery.textScalerOf(context).scale(11) - 11,
                            ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: AnimatedOpacity(
                            opacity: _showPrecision ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: <Widget>[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Detalle · ±${_length(_precisionRange, widget.centimeters, compact: true)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  Expanded(
                                    child: CustomPaint(
                                      key: const ValueKey('x-precision-bar'),
                                      size: const Size(
                                        double.infinity,
                                        double.infinity,
                                      ),
                                      painter: _PositionPainter(
                                        actual: ready ? _visualActual : null,
                                        target: validTarget
                                            ? widget.targetMm
                                            : 0,
                                        tolerance: validTolerance
                                            ? widget.toleranceMm
                                            : 0,
                                        range: _precisionRange,
                                        centimeters: widget.centimeters,
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
                      SizedBox(
                        height: 88,
                        width: double.infinity,
                        child: CustomPaint(
                          key: const ValueKey('x-position-bar'),
                          painter: _PositionPainter(
                            actual: ready ? _visualActual : null,
                            target: validTarget ? widget.targetMm : 0,
                            tolerance: validTolerance ? widget.toleranceMm : 0,
                            range: range,
                            centimeters: widget.centimeters,
                            colors: colors,
                            successColor: successColor,
                          ),
                        ),
                      ),
                      Text(
                        'Escala ±${_length(range, widget.centimeters, compact: true)}'
                        ' · tolerancia ${validTolerance ? '±${_length(widget.toleranceMm, widget.centimeters, compact: true)}' : '—'}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
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

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 32 || size.height < (precision ? 36 : 70)) return;
    final double inset = math.min(36, size.width * 0.12);
    final double left = inset;
    final double right = size.width - inset;
    final double center = size.width / 2;
    final double halfWidth = (right - left) / 2;
    final double y = precision ? 20 : 34;
    final double thickness = precision ? 3 : 5;
    final Rect bar = Rect.fromLTRB(left, y - thickness, right, y + thickness);
    final RRect roundedBar = RRect.fromRectAndRadius(
      bar,
      const Radius.circular(5),
    );
    canvas.drawRRect(
      roundedBar,
      Paint()..color = colors.surfaceContainerHighest,
    );

    if (actual != null && tolerance > 0) {
      // Exact tolerance-to-scale ratio; never enforce a decorative minimum width.
      final double bandHalfWidth = halfWidth * (tolerance / range);
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
    for (int i = -2; i <= 2; i++) {
      if (precision && i.abs() == 1) continue;
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
          text:
              '${delta > 0 ? '+' : ''}${_length(delta, centimeters, compact: true)}',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 10,
            color: colors.onSurfaceVariant,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: math.max(1, halfWidth));
      label.paint(
        canvas,
        Offset(
          (x - label.width / 2).clamp(0, size.width - label.width).toDouble(),
          y + (precision ? 14 : 27),
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
