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
    final c = controller;
    final job = c.job;
    final step = c.step;
    if (job == null || step == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.polyline_outlined,
                size: 64,
                color: Color(0xff187ba9),
              ),
              const SizedBox(height: 20),
              const Text('Tu próximo diseño empieza aquí'),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: c.importJob,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('Importar patrón'),
              ),
              TextButton(
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
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cambiar patrón',
                      onPressed: c.importJob,
                      icon: const Icon(Icons.folder_open_outlined),
                    ),
                  ],
                ),
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
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (c.stepIndex + 1) / job.steps.length,
                  minHeight: 3,
                  backgroundColor: const Color(0xffe4edf3),
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
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: 'Ángulo R',
                        value: '${step.angleR.toStringAsFixed(1)}°',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Metric(
                        label: 'Profundidad',
                        value: c.length(step.depth),
                      ),
                    ),
                  ],
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
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
                Text(
                  c.compensationActive
                      ? 'Compensación activa · ${c.profile.name}'
                      : 'Sin compensación de montaje',
                  style: Theme.of(context).textTheme.bodySmall,
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
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ],
      ),
    ),
  );
}
