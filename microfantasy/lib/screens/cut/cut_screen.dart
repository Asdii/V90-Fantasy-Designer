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
    Widget preview() => Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: job.cutHelper != null
              ? V90CutHelper(
                  data: job.cutHelper!,
                  stepIndex: c.stepIndex,
                  angleDeg: step.angleR,
                  direction: c.helperDirection,
                  zeroView: c.helperZeroView,
                )
              : PatternPreview(
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
        if (job.cutHelper != null)
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              tooltip: 'Abrir Cut Helper',
              onPressed: () => showFullCutHelper(context, c),
              icon: const Icon(Icons.open_in_full, size: 19),
            ),
          ),
      ],
    );

    final summary = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              Text(
                'Paso ${c.stepIndex + 1} de ${job.steps.length}',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                c.compensationActive
                    ? 'Compensación activa'
                    : 'Sin compensación de montaje',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Ángulo R', style: theme.textTheme.labelMedium),
            Text(
              '${step.angleR.toStringAsFixed(1)}°',
              style: theme.textTheme.titleLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: colors.primary,
              ),
            ),
          ],
        ),
      ],
    );
    final guide = XPositionGuide(
      actualMm: c.actualX,
      targetMm: c.correctedTarget,
      toleranceMm: c.settings.tolerance,
      smoothing: c.settings.smoothing.name,
      centimeters: c.settings.units.name == 'cm',
    );
    final navigation = Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: c.stepIndex > 0 ? c.previousStep : null,
              icon: const Icon(Icons.arrow_back),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Anterior', maxLines: 1),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: c.stepIndex < job.steps.length - 1 ? c.nextStep : null,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Siguiente', maxLines: 1),
              ),
            ),
          ),
        ],
      ),
    );
    // Only the drawing flexes. Readings, the X ruler and navigation retain
    // their dimensions when a large V90 pattern or a new step arrives.
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 560 && constraints.maxHeight < 570) {
            return Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      summary,
                      Expanded(child: preview()),
                      navigation,
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [guide],
                  ),
                ),
              ],
            );
          }
          if (constraints.maxHeight < 440) {
            return Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: constraints.maxWidth * .62,
                            child: summary,
                          ),
                        ),
                      ),
                      Expanded(flex: 2, child: preview()),
                    ],
                  ),
                ),
                guide,
                navigation,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              summary,
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: (c.stepIndex + 1) / job.steps.length,
                minHeight: 2,
                backgroundColor: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
              Expanded(child: preview()),
              guide,
              navigation,
            ],
          );
        },
      ),
    );
  }
}
