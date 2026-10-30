import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import 'v90_cut_helper.dart';

class CutHelperControls extends StatelessWidget {
  const CutHelperControls({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 6,
    runSpacing: 4,
    children: [
      ChoiceChip(
        label: const Text('Horizontal →'),
        selected: controller.helperDirection == 'horizontal',
        onSelected: (_) => controller.setHelperDirection('horizontal'),
      ),
      ChoiceChip(
        label: const Text('Vertical ↑'),
        selected: controller.helperDirection == 'vertical',
        onSelected: (_) => controller.setHelperDirection('vertical'),
      ),
      TextButton(
        onPressed: () => controller.setHelperZero(!controller.helperZeroView),
        child: Text(
          controller.helperZeroView ? 'Orientar al corte' : 'Volver a 0°',
        ),
      ),
    ],
  );
}

Future<void> showFullCutHelper(
  BuildContext context,
  AppController controller,
) => showDialog<void>(
  context: context,
  builder: (context) => Dialog.fullscreen(
    child: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final job = controller.job;
          final data = job?.cutHelper;
          if (data == null) {
            return Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            );
          }
          final current = data.steps[controller.stepIndex];
          return Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Cut Helper · V90',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                'Operación ${current.operationNumber} · Faceta de referencia ${data.referenceFacetId}',
              ),
              CutHelperControls(controller: controller),
              Expanded(
                child: Center(
                  child: V90CutHelper(
                    data: data,
                    stepIndex: controller.stepIndex,
                    angleDeg: controller.step!.angleR,
                    direction: controller.helperDirection,
                    zeroView: controller.helperZeroView,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 18,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      'Paso ${controller.stepIndex + 1} / ${job!.steps.length}',
                    ),
                    Text('R ${controller.step!.angleR.toStringAsFixed(1)}°'),
                    Text('Distancia ${controller.length(current.distanceMm)}'),
                    Text(
                      'Profundidad ${controller.length(controller.step!.depth)}',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: controller.stepIndex > 0
                            ? controller.previousStep
                            : null,
                        child: const Text('← Anterior'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: controller.stepIndex < job.steps.length - 1
                            ? controller.nextStep
                            : null,
                        child: const Text('Siguiente →'),
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
);
