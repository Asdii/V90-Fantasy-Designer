import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/app_controller.dart';
import '../../widgets/pattern_preview.dart';
import '../../widgets/x_position_guide.dart';
import '../../widgets/v90_cut_helper.dart';
import '../../widgets/cut_helper_controls.dart';

class CutScreen extends StatelessWidget {
  const CutScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final c = controller;
    final job = c.job;
    final step = c.step;
    if (job == null || step == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.polyline_outlined, size: 48, color: colors.primary),
              const SizedBox(height: 20),
              Text(
                'Tu próximo diseño empieza aquí',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                c.receiverSupported
                    ? 'Abre V90 Fantasy Designer en la misma red Wi-Fi y envía '
                          'tu diseño. La recepción está activa mientras esta '
                          'app esté abierta.'
                    : 'Envía tu diseño desde V90 Fantasy Designer a MicroFantasy '
                          'en tu teléfono, con ambos dispositivos en la misma red Wi-Fi.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: c.loadDemo,
                child: const Text('Probar un ejemplo'),
              ),
            ],
          ),
        ),
      );
    }
    final segments = job.preview?.segments;
    final lines =
        segments
            ?.map(
              (s) => [Offset(s.start.x, s.start.y), Offset(s.end.x, s.end.y)],
            )
            .toList() ??
        job.steps.map((s) {
          final a = s.angleR * math.pi / 180;
          return [
            Offset(.5 - .4 * math.cos(a), .5 - .4 * math.sin(a)),
            Offset(.5 + .4 * math.cos(a), .5 + .4 * math.sin(a)),
          ];
        }).toList();
    final active = segments == null
        ? c.stepIndex
        : segments.indexWhere((s) => s.stepIndex == step.index);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const PageStorageKey('cut-scroll'),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(job.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Paso ${c.stepIndex + 1} de ${job.steps.length}',
                      ),
                    ),
                    Text(
                      c.settings.simulation
                          ? 'Simulación'
                          : c.actualX == null
                          ? 'Sin lectura'
                          : 'Conectado',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (c.stepIndex + 1) / job.steps.length,
                  minHeight: 3,
                  backgroundColor: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
                if (job.cutHelper != null) ...[
                  SizedBox(
                    height: 260,
                    child: V90CutHelper(
                      data: job.cutHelper!,
                      stepIndex: c.stepIndex,
                      angleDeg: step.angleR,
                      direction: c.helperDirection,
                      zeroView: c.helperZeroView,
                    ),
                  ),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        'Desde el centro: ${c.length(job.cutHelper!.steps[c.stepIndex].distanceMm)}',
                      ),
                      TextButton.icon(
                        onPressed: () => showFullCutHelper(context, c),
                        icon: const Icon(Icons.open_in_full),
                        label: const Text('Abrir Cut Helper'),
                      ),
                    ],
                  ),
                ] else
                  SizedBox(
                    height: 170,
                    child: PatternPreview(
                      lines: lines,
                      activeIndex: active,
                      activeIndices: segments == null
                          ? null
                          : {
                              for (var i = 0; i < segments.length; i++)
                                if (segments[i].stepIndex == step.index) i,
                            },
                    ),
                  ),
                if (segments == null && job.cutHelper == null)
                  const Text(
                    'Esquema de direcciones · sin trazado adjunto',
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 12),
                _Metric(
                  label: 'Ángulo R',
                  value: '${step.angleR.toStringAsFixed(1)}°',
                ),
                const SizedBox(height: 14),
                XPositionGuide(
                  actualMm: c.actualX,
                  targetMm: c.correctedTarget,
                  toleranceMm: c.settings.tolerance,
                  smoothing: c.settings.smoothing.name,
                  centimeters: c.settings.units.name == 'cm',
                ),
                if (job.cutHelper != null)
                  Text(
                    'X del centro: ${c.length(job.cutHelper!.machineCenterXmm)} · posiciones X con signo',
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
                Text(
                  c.compensationActive
                      ? 'Compensación activa'
                      : 'Sin compensación de montaje',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: c.stepIndex > 0 ? c.previousStep : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Anterior'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: c.stepIndex < job.steps.length - 1
                        ? c.nextStep
                        : null,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Siguiente'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
        ],
      ),
    ),
  );
}
