import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../widgets/calibration_map.dart';
import '../../widgets/common.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _savedPulse;
  late final Animation<double> _savedOpacity;
  late int _lastSavedId;
  double? _savedAngle;

  @override
  void initState() {
    super.initState();
    _savedPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _savedOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_savedPulse);
    _lastSavedId = widget.controller.calibrationSavedId;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant CalibrationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onControllerChanged);
    _savedPulse.reset();
    _savedAngle = null;
    _lastSavedId = widget.controller.calibrationSavedId;
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final c = widget.controller;
    if (_lastSavedId != c.calibrationSavedId) {
      _lastSavedId = c.calibrationSavedId;
      // Auto-advance can already have changed calibrationAngle by this point.
      _savedAngle = c.lastSavedCalibrationAngle;
      if (_savedAngle != null) _savedPulse.forward(from: 0);
    }
    setState(() {});
  }

  Future<void> _confirmReset({bool removingReference = false}) async {
    final c = widget.controller;
    final accepted = await confirm(
      context,
      removingReference ? 'Eliminar referencia de 0°' : 'Reiniciar calibración',
      'Se eliminarán la referencia de 0° y todos los puntos medidos. '
      'La calibración volverá a comenzar en 0°.',
    );
    if (!mounted || widget.controller != c || !accepted) return;
    _savedPulse.reset();
    c.resetCalibration();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _savedPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final angle = c.calibrationAngle;
    final hasReference = c.hasCalibrationReference;
    final actualX = c.actualX;
    final offsets = {
      for (final p in c.profile.points) p.angleR: p.x - c.profile.referenceX,
    };
    final measured = actualX == null || !hasReference
        ? null
        : actualX - c.profile.referenceX;
    final deviationLabel = !hasReference
        ? 'Pendiente de referencia en 0°'
        : measured == null
        ? 'Sin lectura'
        : c.length(measured, signed: true);
    final savedCount = c.angles.where(offsets.containsKey).length;
    final success = ColorScheme.fromSeed(
      seedColor: Colors.green,
      brightness: theme.brightness,
    ).primary;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const PageStorageKey('calibration-scroll'),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Un montaje, una referencia',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Cada punto se guarda automáticamente y se usa para compensar X.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$savedCount / ${c.angles.length} puntos guardados',
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: IgnorePointer(
                        child: FadeTransition(
                          key: const ValueKey('calibration-saved-feedback'),
                          opacity: _savedOpacity,
                          child: Semantics(
                            liveRegion: true,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                  color: success,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    _savedAngle == null
                                        ? 'Punto guardado'
                                        : '${_savedAngle!.toStringAsFixed(0)}° guardado',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(color: success),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: c.angles.isEmpty ? 0 : savedCount / c.angles.length,
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(3),
                  backgroundColor: colors.surfaceContainerHighest,
                  semanticsLabel:
                      'Puntos de calibración guardados: $savedCount de ${c.angles.length}',
                ),
                const SizedBox(height: 12),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: CalibrationMap(
                      offsets: offsets,
                      currentAngle: angle,
                      angles: c.angles,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Section(
                  title: 'Ángulo ${angle.toStringAsFixed(0)}°',
                  children: [
                    Text(
                      hasReference
                          ? 'Gira R a ${angle.toStringAsFixed(0)}° y mueve X hasta centrar la punta con el disco.'
                          : 'Comienza con R en 0°. Mueve X hasta centrar la punta con el disco y guarda la referencia.',
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'X actual: ${actualX == null ? 'Sin lectura' : c.length(actualX)}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Desviación X: $deviationLabel',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (offsets.containsKey(angle)) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            if (angle == 0) {
                              _confirmReset(removingReference: true);
                            } else {
                              c.removeCalibrationPoint();
                            }
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(
                            angle == 0
                                ? 'Eliminar referencia'
                                : 'Eliminar punto',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: offsets.isEmpty ? null : () => _confirmReset(),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.onSurfaceVariant,
                    ),
                    child: const Text('Reiniciar calibración'),
                  ),
                ),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasReference
                        ? 'X: ${actualX == null ? 'Sin lectura' : c.length(actualX)}'
                        : 'Guarda la referencia de 0° para continuar.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          actualX == null ||
                              !actualX.isFinite ||
                              (!hasReference && angle != 0)
                          ? null
                          : c.saveCalibrationPoint,
                      icon: const Icon(Icons.check),
                      label: Text(
                        !hasReference
                            ? 'Establecer referencia en 0°'
                            : offsets.containsKey(angle)
                            ? 'Rehacer punto'
                            : 'Guardar punto',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: hasReference ? c.previousAngle : null,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Anterior'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: hasReference ? c.nextAngle : null,
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Siguiente'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
