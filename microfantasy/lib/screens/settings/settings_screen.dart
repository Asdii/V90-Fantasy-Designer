import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/app_controller.dart';
import '../../models/app_settings.dart';
import '../../widgets/common.dart';
import '../../widgets/app_updates.dart';
import '../../services/esp32/provisioning_service.dart';
import 'machine_setup_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final s = c.settings;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('A tu manera', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 18),
        AppUpdatesCard(controller: c.updates),
        const SizedBox(height: 14),
        Section(
          title: 'Máquina',
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Modo simulación'),
              value: s.simulation,
              onChanged: (v) => c.updateSettings(s.copyWith(simulation: v)),
            ),
            Text(c.connectionLabel),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dirección de la máquina'),
              subtitle: Text(s.host),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () async {
                final v = await askText(
                  context,
                  'Hostname o IP',
                  initial: s.host,
                );
                if (v != null && v.isNotEmpty) c.changeHost(v);
              },
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final ip = await showDialog<String>(
                      context: context,
                      builder: (_) => MachineSetupDialog(
                        service: HttpMachineProvisioningService(),
                      ),
                    );
                    if (ip != null) {
                      await c.updateSettings(
                        c.settings.copyWith(
                          host: ip,
                          port: 81,
                          simulation: false,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add_link),
                  label: const Text('Configurar Wi-Fi de la máquina'),
                ),
                OutlinedButton.icon(
                  onPressed: c.busy ? null : c.discoverMachine,
                  icon: const Icon(Icons.wifi_find),
                  label: const Text('Buscar máquina'),
                ),
                OutlinedButton(
                  onPressed: c.busy ? null : c.testConnection,
                  child: const Text('Probar conexión'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Section(
          title: 'V90 Fantasy Designer',
          children: [
            Text(c.receiverLabel),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Recibir por Wi-Fi'),
              value: c.receiving,
              onChanged: c.receiverSupported ? c.toggleReceiver : null,
            ),
            if (c.receiving) ...[
              SelectableText(c.receiverAddress),
              const SizedBox(height: 6),
              SelectableText('Código de enlace: ${c.pairingToken ?? ''}'),
              TextButton.icon(
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: c.pairingToken ?? ''),
                ),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copiar código'),
              ),
            ],
            OutlinedButton.icon(
              onPressed: c.importJob,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Importar archivo JSON'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Section(
          title: 'Preferencias',
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.light_mode_outlined),
              title: Text('Apariencia clara'),
            ),
            _choice<LengthUnit>('Unidad', s.units, {
              LengthUnit.mm: 'Milímetros',
              LengthUnit.cm: 'Centímetros',
            }, (v) => c.updateSettings(s.copyWith(units: v))),
            _choice<bool>('Dirección X', s.invertX, {
              false: 'Normal',
              true: 'Invertida',
            }, (v) => c.updateSettings(s.copyWith(invertX: v))),
            _choice<SmoothingLevel>('Suavizado visual', s.smoothing, {
              SmoothingLevel.off: 'Desactivado',
              SmoothingLevel.light: 'Suave',
              SmoothingLevel.medium: 'Medio',
            }, (v) => c.updateSettings(s.copyWith(smoothing: v))),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tolerancia objetivo'),
              subtitle: Text('±${c.length(s.tolerance)}'),
              trailing: const Icon(Icons.tune),
              onTap: () async {
                final v = await askText(
                  context,
                  'Tolerancia en mm',
                  initial: s.tolerance.toString(),
                  numeric: true,
                );
                if (v != null) c.changeTolerance(v);
              },
            ),
            Wrap(
              spacing: 8,
              children: [.02, .05, .10]
                  .map(
                    (v) => ChoiceChip(
                      label: Text('±$v mm'),
                      selected: s.tolerance == v,
                      onSelected: (_) =>
                          c.updateSettings(s.copyWith(tolerance: v)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            _choice<int>('Intervalo de calibración', s.angleInterval, {
              45: '45°',
              30: '30°',
              15: '15°',
              if (![45, 30, 15].contains(s.angleInterval))
                s.angleInterval: '${s.angleInterval}°',
            }, (v) => c.updateSettings(s.copyWith(angleInterval: v))),
            TextButton(
              onPressed: () async {
                final v = await askText(
                  context,
                  'Intervalo personalizado (grados)',
                  initial: '${s.angleInterval}',
                  numeric: true,
                );
                if (v != null) c.changeInterval(v);
              },
              child: const Text('Intervalo personalizado'),
            ),
            _choice<String>('Perfil activo', c.profile.id, {
              for (final p in c.profiles) p.id: p.name,
            }, c.selectProfile),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vibrar al centrar'),
              value: s.haptics,
              onChanged: (v) => c.updateSettings(s.copyWith(haptics: v)),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Avanzar al guardar punto'),
              value: s.autoAdvance,
              onChanged: (v) => c.updateSettings(s.copyWith(autoAdvance: v)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Section(
          title: 'Datos',
          children: [
            _action(
              Icons.download_outlined,
              'Exportar calibraciones',
              c.exportCalibrations,
            ),
            _action(
              Icons.upload_file_outlined,
              'Importar calibraciones',
              c.importCalibrations,
            ),
            _action(
              Icons.polyline_outlined,
              'Cargar patrón de ejemplo',
              c.loadDemo,
            ),
            _action(Icons.delete_outline, 'Borrar trabajo actual', () async {
              if (await confirm(
                context,
                'Borrar trabajo actual',
                'Los perfiles de calibración se conservarán.',
              )) {
                c.clearJob();
              }
            }),
            _action(Icons.restart_alt, 'Restaurar configuración', () async {
              if (await confirm(
                context,
                'Restaurar configuración',
                'Se conservarán trabajos y calibraciones.',
              )) {
                c.resetSettings();
              }
            }),
          ],
        ),
        const SizedBox(height: 14),
        ExpansionTile(
          title: const Text('Opciones avanzadas'),
          children: [
            ListTile(
              title: const Text('Puerto WebSocket'),
              subtitle: Text('${s.port}'),
              onTap: () async {
                final v = await askText(
                  context,
                  'Puerto WebSocket',
                  initial: '${s.port}',
                  numeric: true,
                );
                if (v != null) c.changePort(v);
              },
            ),
            ListTile(
              title: const Text('Timeout'),
              subtitle: Text('${s.timeoutSeconds} segundos'),
              onTap: () async {
                final v = await askText(
                  context,
                  'Timeout en segundos',
                  initial: '${s.timeoutSeconds}',
                  numeric: true,
                );
                if (v != null) c.changeTimeout(v);
              },
            ),
            if (s.simulation) ...[
              Text('X simulado: ${c.length(c.rawX ?? 0)}'),
              Slider(
                min: -30,
                max: 30,
                value: (c.rawX ?? 0).clamp(-30, 30),
                onChanged: c.simulateX,
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () =>
                        c.simulateX(c.correctedTarget * (s.invertX ? -1 : 1)),
                    child: const Text('Ir al objetivo'),
                  ),
                  TextButton(
                    onPressed: c.animateSimulation,
                    child: const Text('Animar lectura'),
                  ),
                ],
              ),
            ],
            SelectableText(
              c.diagnostics,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    onTap: onTap,
  );
  Widget _choice<T>(
    String label,
    T value,
    Map<T, String> options,
    ValueChanged<T> onChange,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<T>(
      key: ValueKey('$label:$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChange(v);
      },
    ),
  );
}
