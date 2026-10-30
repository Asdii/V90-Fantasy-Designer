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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late double _rangeFrom;
  late double _rangeTo;
  double? _actualFrom;
  double? _actualTo;

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

  static double _range(XPositionGuide guide) {
    final double? actual = _finite(guide.actualMm);
    final double distance = actual != null && guide.targetMm.isFinite
        ? (actual - guide.targetMm).abs()
        : double.infinity;
    final double band = distance <= 0.15 ? 0.2 : (distance <= 0.8 ? 1.0 : 5.0);
    final double floor = _validTolerance(guide.toleranceMm)
        ? guide.toleranceMm * 8
        : 0;
    return math.max(band, floor.isFinite ? floor : double.maxFinite);
  }

  double get _progress => Curves.easeOutCubic.transform(_controller.value);

  double get _visualRange =>
      _rangeFrom * (1 - _progress) + _rangeTo * _progress;

  double? get _visualActual {
    final double? start = _actualFrom;
    final double? end = _actualTo;
    if (start == null || end == null) return end;
    return start * (1 - _progress) + end * _progress;
  }

  int _zone(double value) {
    final double error = value - widget.targetMm;
    if (error.abs() <= widget.toleranceMm) return 0;
    return error < 0 ? -1 : 1;
  }

  @override
  void initState() {
    super.initState();
    _rangeFrom = _rangeTo = _range(widget);
    _actualFrom = _actualTo = _finite(widget.actualMm);
    _controller = AnimationController(vsync: this, value: 1);
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
    _rangeFrom = _visualRange;
    _rangeTo = _range(widget);
    // Never animate across a tolerance boundary: crossing the green band must
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
    _controller.stop();
    final Duration duration = smoothingDuration != Duration.zero
        ? smoothingDuration
        : _rangeFrom != _rangeTo
        ? const Duration(milliseconds: 180)
        : Duration.zero;
    if (duration == Duration.zero) {
      _controller.value = 1;
    } else {
      _controller.duration = duration;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
    final Color statusColor = arrived
        ? const Color(0xFF227A50)
        : const Color(0xFF17334B);

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'Posición X. Actual $actualLabel. Objetivo $targetLabel. $status.',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF6FAFC),
          borderRadius: BorderRadius.circular(10),
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
                    child: _reading('Actual', actualLabel, TextAlign.left),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _reading('Objetivo', targetLabel, TextAlign.right),
                  ),
                ],
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? child) {
                  // A tolerance increase must never briefly exaggerate the
                  // green width while the scale is catching up.
                  final double floor = validTolerance
                      ? widget.toleranceMm * 8
                      : 0;
                  final double range = math.max(
                    _visualRange,
                    floor.isFinite ? floor : double.maxFinite,
                  );
                  return Column(
                    children: <Widget>[
                      SizedBox(
                        height: 100,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _PositionPainter(
                            actual: ready ? _visualActual : null,
                            target: validTarget ? widget.targetMm : 0,
                            tolerance: validTolerance ? widget.toleranceMm : 0,
                            range: range,
                            centimeters: widget.centimeters,
                          ),
                        ),
                      ),
                      Text(
                        'Escala ±${_length(range, widget.centimeters, compact: true)}'
                        ' · tolerancia ${validTolerance ? '±${_length(widget.toleranceMm, widget.centimeters, compact: true)}' : '—'}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF62798C),
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

  Widget _reading(String label, String value, TextAlign alignment) {
    return Column(
      crossAxisAlignment: alignment == TextAlign.left
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF62798C)),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: alignment,
          style: const TextStyle(
            color: Color(0xFF17334B),
            fontSize: 21,
            fontWeight: FontWeight.w600,
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
  });

  final double? actual;
  final double target;
  final double tolerance;
  final double range;
  final bool centimeters;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 32 || size.height < 70) return;
    final double inset = math.min(36, size.width * 0.12);
    final double left = inset;
    final double right = size.width - inset;
    final double center = size.width / 2;
    final double halfWidth = (right - left) / 2;
    const double y = 41;
    final Rect bar = Rect.fromLTRB(left, y - 5, right, y + 5);
    final RRect roundedBar = RRect.fromRectAndRadius(
      bar,
      const Radius.circular(5),
    );
    canvas.drawRRect(roundedBar, Paint()..color = const Color(0xFFD6DFE5));

    if (actual != null && tolerance > 0) {
      // Exact tolerance-to-scale ratio; never enforce a decorative minimum width.
      final double greenHalfWidth = halfWidth * (tolerance / range);
      final Rect band = Rect.fromLTRB(
        center - greenHalfWidth,
        bar.top,
        center + greenHalfWidth,
        bar.bottom,
      );
      canvas.save();
      canvas.clipRRect(roundedBar);
      canvas.drawRect(
        band,
        Paint()
          ..shader = const LinearGradient(
            colors: <Color>[
              Color(0x0039A96B),
              Color(0xFF54B980),
              Color(0x0039A96B),
            ],
            stops: <double>[0, 0.5, 1],
          ).createShader(band),
      );
      canvas.restore();
    }

    canvas.drawLine(
      Offset(center, y - 13),
      Offset(center, y + 13),
      Paint()
        ..color = const Color(0xFF28AFC2)
        ..strokeWidth = 1.5,
    );
    for (int i = -2; i <= 2; i++) {
      final double fraction = i / 2;
      final double x = center + fraction * halfWidth;
      canvas.drawLine(
        Offset(x, y + 16),
        Offset(x, y + 21),
        Paint()
          ..color = const Color(0xFF9BADB9)
          ..strokeWidth = 1,
      );
      final double delta = fraction * range;
      final TextPainter label = TextPainter(
        text: TextSpan(
          text:
              '${delta > 0 ? '+' : ''}${_length(delta, centimeters, compact: true)}',
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 10,
            color: Color(0xFF62798C),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: math.max(1, halfWidth));
      label.paint(
        canvas,
        Offset(
          (x - label.width / 2).clamp(0, size.width - label.width).toDouble(),
          y + 27,
        ),
      );
      label.dispose();
    }

    final double? live = actual;
    if (live == null) return;
    final double relative = (live - target) / range;
    final double x = center + relative.clamp(-1.0, 1.0).toDouble() * halfWidth;
    final Paint marker = Paint()
      ..color = const Color(0xFF101820)
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
      centimeters != oldDelegate.centimeters;
}
