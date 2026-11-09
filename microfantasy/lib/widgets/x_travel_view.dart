import 'dart:math' as math;

import 'package:flutter/material.dart';

enum XTravelSelection { negative, center, positive }

/// A live, read-only drawing of the manual X table, with selectable references.
///
/// Coordinates are signed millimetres: negativeMm < 0 < positiveMm. Selection
/// only changes the inspected reference; it never moves or captures a position.
/// The marker uses [positionMm] only when [axisReady]. Missing stops are marked
/// as provisional; a complete travel keeps its measured, asymmetric scale.
class XTravelView extends StatelessWidget {
  const XTravelView({
    super.key,
    required this.axisReady,
    this.hasCenter = false,
    this.negativeMm,
    this.positiveMm,
    this.positionMm,
    this.selected,
    this.onSelected,
    this.formatLength,
  });

  final bool axisReady;
  final bool hasCenter;
  final double? negativeMm;
  final double? positiveMm;
  final double? positionMm;
  final XTravelSelection? selected;
  final ValueChanged<XTravelSelection>? onSelected;
  final String Function(double mm)? formatLength;

  String _length(double mm) =>
      formatLength?.call(mm) ??
      '${mm > 0 ? '+' : ''}${mm.toStringAsFixed(3)} mm';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final negative =
        negativeMm != null && negativeMm!.isFinite && negativeMm! < 0
        ? negativeMm
        : null;
    final positive =
        positiveMm != null && positiveMm!.isFinite && positiveMm! > 0
        ? positiveMm
        : null;
    final position = axisReady && positionMm != null && positionMm!.isFinite
        ? positionMm
        : null;
    final complete = negative != null && positive != null;
    final outside =
        position != null &&
        ((negative != null && position < negative) ||
            (positive != null && position > positive));
    final reading = !axisReady
        ? 'Referencia pendiente'
        : position == null
        ? 'Esperando lectura reciente'
        : 'X actual: ${_length(position)}';

    // In a draft, the viewport follows only observed positions and saved stops.
    // Its padding is drawing space, never a proposed or measured endpoint.
    var min = negative ?? math.min(0.0, position ?? 0.0);
    var max = positive ?? math.max(0.0, position ?? 0.0);
    if (!complete) {
      final span = math.max(1.0, max - min);
      if (negative == null) min -= span * .2;
      if (positive == null) max += span * .2;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mesa · recorrido X', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              reading,
              key: const ValueKey('x-travel-reading'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: position == null
                    ? colors.onSurfaceVariant
                    : colors.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (outside)
              Text(
                'Fuera del recorrido guardado',
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: SizedBox(
                height: 124,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const inset = 20.0;
                    final width = math.max(
                      1.0,
                      constraints.maxWidth - inset * 2,
                    );
                    double x(double mm) =>
                        inset +
                        ((max - mm) / (max - min)).clamp(0.0, 1.0) * width;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _TravelTablePainter(
                              colors: colors,
                              complete: complete,
                            ),
                          ),
                        ),
                        if (negative != null)
                          _stop(
                            x(negative),
                            colors,
                            XTravelSelection.negative,
                            'x-travel-negative-stop',
                          ),
                        if (positive != null)
                          _stop(
                            x(positive),
                            colors,
                            XTravelSelection.positive,
                            'x-travel-positive-stop',
                          ),
                        Positioned(
                          left: x(0) - 1,
                          top: 42,
                          width: 2,
                          height: 70,
                          child: ColoredBox(
                            key: const ValueKey('x-travel-zero'),
                            color: hasCenter || axisReady
                                ? colors.primary
                                : colors.outlineVariant,
                          ),
                        ),
                        Positioned(
                          left: x(0) - 10,
                          top: 102,
                          width: 20,
                          child: Text(
                            hasCenter || axisReady ? '0' : '?',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                        if (position != null)
                          Positioned(
                            left: x(position) - 10,
                            top: 4,
                            width: 20,
                            height: 85,
                            child: Column(
                              key: const ValueKey('x-travel-live-marker'),
                              children: [
                                Icon(
                                  outside
                                      ? position < 0
                                            ? Icons.arrow_right
                                            : Icons.arrow_left
                                      : Icons.arrow_drop_down,
                                  color: outside
                                      ? colors.error
                                      : colors.primary,
                                  size: 20,
                                ),
                                Expanded(
                                  child: Container(
                                    width: 3,
                                    color: outside
                                        ? colors.error
                                        : colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _reference(
                    context,
                    XTravelSelection.positive,
                    'Tope +',
                    positive == null ? 'Sin guardar' : _length(positive),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _reference(
                    context,
                    XTravelSelection.center,
                    'Centro 0',
                    axisReady
                        ? 'Referenciado'
                        : hasCenter
                        ? 'Guardado'
                        : 'Pendiente',
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _reference(
                    context,
                    XTravelSelection.negative,
                    'Tope −',
                    negative == null ? 'Sin guardar' : _length(negative),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              complete
                  ? 'Recorrido total: ${_length(positive - negative)}'
                  : 'Vista provisional · la escala se completa al guardar ambos topes.',
              style: theme.textTheme.bodySmall,
            ),
            if (onSelected != null) ...[
              const SizedBox(height: 4),
              Text(
                'Toca una referencia para ver su detalle.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stop(
    double x,
    ColorScheme colors,
    XTravelSelection reference,
    String key,
  ) => Positioned(
    left: x - 5,
    top: 48,
    width: 10,
    height: 48,
    child: DecoratedBox(
      key: ValueKey(key),
      decoration: BoxDecoration(
        color: selected == reference ? colors.primary : colors.onSurfaceVariant,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );

  Widget _reference(
    BuildContext context,
    XTravelSelection reference,
    String title,
    String value,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final active = selected == reference;
    return Semantics(
      button: true,
      selected: active,
      enabled: onSelected != null,
      label: '$title. $value',
      excludeSemantics: true,
      onTap: onSelected == null ? null : () => onSelected!(reference),
      child: Material(
        color: active ? colors.primaryContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey('x-travel-select-${reference.name}'),
          borderRadius: BorderRadius.circular(8),
          onTap: onSelected == null ? null : () => onSelected!(reference),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TravelTablePainter extends CustomPainter {
  const _TravelTablePainter({required this.colors, required this.complete});

  final ColorScheme colors;
  final bool complete;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 20.0;
    final right = size.width - left;
    final table = RRect.fromRectAndRadius(
      Rect.fromLTRB(left, 48, right, 96),
      const Radius.circular(6),
    );
    canvas.drawRRect(table, Paint()..color = colors.surfaceContainerHighest);
    final rail = Paint()
      ..color = colors.outline
      ..strokeWidth = 1;
    for (final y in [58.0, 86.0]) {
      if (complete) {
        canvas.drawLine(Offset(left, y), Offset(right, y), rail);
      } else {
        for (var x = left; x < right; x += 10) {
          canvas.drawLine(
            Offset(x, y),
            Offset(math.min(x + 5, right), y),
            rail,
          );
        }
      }
    }
    if (complete) {
      for (var i = 0; i <= 20; i++) {
        final x = left + (right - left) * i / 20;
        canvas.drawLine(Offset(x, 86), Offset(x, i % 5 == 0 ? 70 : 78), rail);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TravelTablePainter oldDelegate) =>
      oldDelegate.colors != colors || oldDelegate.complete != complete;
}
