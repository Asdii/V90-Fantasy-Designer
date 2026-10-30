import 'package:flutter/material.dart';
import '../../app/app_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/calibration_map.dart';

class CalibrationScreen extends StatelessWidget {
  const CalibrationScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final angle = c.calibrationAngle;
    final offsets = {
      for (final p in c.profile.points) p.angleR: p.x - c.profile.referenceX,
    };
    final measured = c.actualX == null || c.profile.points.isEmpty
        ? null
        : c.actualX! - c.profile.referenceX;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Un montaje, una referencia',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: c.profile.id,
                        isExpanded: true,
                        key: ValueKey(c.profile.id),
                        decoration: const InputDecoration(labelText: 'Perfil'),
                        items: c.profiles
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.name),
                              ),
                            )
                            .toList(),
                        onChanged: (id) {
                          if (id != null) c.selectProfile(id);
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Nuevo perfil',
                      onPressed: () async {
                        final name = await askText(
                          context,
                          'Nombre del montaje',
                        );
                        if (name != null && name.isNotEmpty) c.addProfile(name);
                      },
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${c.angles.where(offsets.containsKey).length} / ${c.angles.length} puntos guardados',
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: CalibrationMap(
                      offsets: offsets,
                      currentAngle: angle,
                      angles: c.angles,
                    ),
                  ),
                ),
                const Text(
                  'Más cerca del círculo gris, mejor centrado.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Section(
                  title: 'Ángulo ${angle.toStringAsFixed(0)}°',
                  children: [
                    Text(
                      'Gira R a ${angle.toStringAsFixed(0)}° y mueve X hasta centrar la punta con el disco.',
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'X actual: ${c.actualX == null ? 'Sin lectura' : c.length(c.actualX!)}',
                    ),
                    Text(
                      'Offset X: ${measured == null ? 'Establece una referencia' : c.length(measured, signed: true)}',
                    ),
                    if (offsets.containsKey(angle))
                      TextButton.icon(
                        onPressed: c.removeCalibrationPoint,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Eliminar punto'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: c.saveCalibration,
                      child: const Text('Guardar calibración'),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (await confirm(
                          context,
                          'Reiniciar este perfil',
                          'Se eliminarán sus puntos medidos.',
                        )) {
                          c.resetCalibration();
                        }
                      },
                      child: const Text('Reiniciar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'X: ${c.actualX == null ? 'Sin lectura' : c.length(c.actualX!)}${measured == null ? '' : ' · Offset ${c.length(measured, signed: true)}'}',
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: c.actualX == null
                        ? null
                        : c.saveCalibrationPoint,
                    icon: const Icon(Icons.check),
                    label: Text(
                      c.profile.points.isEmpty
                          ? 'Establecer referencia'
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
                        onPressed: c.previousAngle,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Anterior'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: c.nextAngle,
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
      ],
    );
  }
}
