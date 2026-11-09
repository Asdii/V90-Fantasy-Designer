import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Status only. Discovery/reconnection belongs to the service, not to a tap.
class MachineConnectionIndicator extends StatefulWidget {
  const MachineConnectionIndicator({
    super.key,
    required this.connected,
    required this.simulation,
    this.connectionLabel,
    this.machineAddress,
  });
  final bool connected, simulation;
  final String? connectionLabel, machineAddress;

  @override
  State<MachineConnectionIndicator> createState() =>
      _MachineConnectionIndicatorState();
}

class _MachineConnectionIndicatorState extends State<MachineConnectionIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _signal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _reducedMotion = false;
  bool _searching = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    _reducedMotion = media.disableAnimations || media.accessibleNavigation;
    _sync();
  }

  @override
  void didUpdateWidget(covariant MachineConnectionIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(arrived: widget.connected && !oldWidget.connected);
  }

  void _sync({bool arrived = false}) {
    if (widget.simulation || _reducedMotion) {
      _searching = false;
      _signal.stop();
      _signal.value = 1;
    } else if (!widget.connected) {
      if (!_searching || !_signal.isAnimating) {
        _signal.repeat(period: const Duration(milliseconds: 2200));
      }
      _searching = true;
    } else if (arrived) {
      _searching = false;
      _signal.forward(from: 0);
    } else if (!_signal.isAnimating) {
      _searching = false;
      _signal.value = 1;
    }
  }

  @override
  void dispose() {
    _signal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = widget.simulation
        ? 'Simulación'
        : widget.connected
        ? 'Conectada'
        : 'Buscando…';
    final description = widget.simulation
        ? 'Modo simulación'
        : widget.connected
        ? 'Máquina conectada'
        : 'Buscando conexión con la máquina';
    final color = widget.simulation
        ? colors.onSurfaceVariant
        : widget.connected
        ? (colors.brightness == Brightness.dark
              ? const Color(0xff77d7a5)
              : const Color(0xff21764e))
        : colors.primary;
    return Tooltip(
      message: [
        description,
        if (widget.connectionLabel != null) widget.connectionLabel!,
        if (!widget.simulation && widget.machineAddress != null)
          widget.machineAddress!,
      ].join('\n'),
      excludeFromSemantics: true,
      child: Semantics(
        key: const ValueKey('machine-connection-indicator'),
        liveRegion: true,
        label: description,
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 44,
              child: AnimatedBuilder(
                animation: _signal,
                builder: (context, _) => CustomPaint(
                  painter: _SignalPainter(
                    progress: _signal.value,
                    connected: widget.connected,
                    active: !widget.simulation && !_reducedMotion,
                    color: color,
                  ),
                  child: Center(
                    child: Icon(
                      widget.simulation
                          ? Icons.science_outlined
                          : widget.connected
                          ? Icons.wifi
                          : Icons.wifi_find,
                      size: 17,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalPainter extends CustomPainter {
  const _SignalPainter({
    required this.progress,
    required this.connected,
    required this.active,
    required this.color,
  });
  final double progress;
  final bool connected, active;
  final Color color;
  // Fixed irregular spacing: no random flicker when telemetry rebuilds the UI.
  static const angles = [
    .06,
    .51,
    1.12,
    1.69,
    2.03,
    2.83,
    3.31,
    3.88,
    4.35,
    5.08,
    5.72,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (!active || (connected && progress >= 1)) return;
    final center = size.center(Offset.zero);
    for (var i = 0; i < angles.length; i++) {
      final phase = connected ? progress : (progress + i * .137) % 1;
      final eased = Curves.easeOutCubic.transform(phase);
      final radius = 11 + 8 * eased;
      final length = (connected ? 6 : 4) * (1 - eased) + .5;
      final opacity = connected
          ? math.pow(1 - phase, 1.6).toDouble()
          : math.sin(phase * math.pi) * .65;
      final direction = Offset(math.cos(angles[i]), math.sin(angles[i]));
      canvas.drawLine(
        center + direction * radius,
        center + direction * (radius + length),
        Paint()
          ..color = color.withValues(alpha: opacity.clamp(0, 1))
          ..strokeWidth = connected ? 1.6 : 1.2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SignalPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      connected != oldDelegate.connected ||
      active != oldDelegate.active ||
      color != oldDelegate.color;
}
