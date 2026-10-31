import 'package:flutter/material.dart';
import '../../app/app_controller.dart';
import '../../app/theme.dart';
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
      key: const PageStorageKey('settings-scroll'),
      padding: const EdgeInsets.all(18),
      children: [
        Text('A tu manera', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 18),
        Section(
          title: 'Máquina',
          children: [
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(c.receiving ? Icons.wifi : Icons.wifi_off),
              title: Text(
                c.receiving
                    ? 'Lista para recibir diseños'
                    : c.receiverSupported
                    ? 'Preparando recepción Wi-Fi'
                    : 'Recepción Wi-Fi no disponible',
              ),
            ),
            if (c.receiverSupported && !c.receiving)
              OutlinedButton.icon(
                onPressed: c.busy ? null : c.ensureReceiver,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar recepción'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Section(
          title: 'Preferencias',
          children: [
            _choice<LengthUnit>('Unidad', s.units, {
              LengthUnit.mm: 'Milímetros',
              LengthUnit.cm: 'Centímetros',
            }, (v) => c.updateSettings(s.copyWith(units: v))),
            _choice<SmoothingLevel>('Respuesta visual', s.smoothing, {
              SmoothingLevel.off: 'Ligero',
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
              runSpacing: 8,
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
          title: 'Temas',
          children: [
            const Text(
              'Elige el ambiente de tu taller. Seis temas claros y uno nocturno.',
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns =
                    constraints.maxWidth >= 600 &&
                    MediaQuery.textScalerOf(context).scale(16) <= 20;
                final width = twoColumns
                    ? (constraints.maxWidth - 10) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final appearance in AppearanceTheme.values)
                      SizedBox(
                        width: width,
                        child: _AppearanceCard(
                          key: ValueKey(appearance),
                          appearance: appearance,
                          selected: s.appearance == appearance,
                          onTap: () => c.updateSettings(
                            c.settings.copyWith(appearance: appearance),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        Section(
          title: 'Datos',
          children: [
            _action(
              Icons.download_outlined,
              'Exportar calibración',
              c.exportCalibrations,
            ),
            _action(
              Icons.upload_file_outlined,
              'Importar calibración',
              () async {
                if (await confirm(
                  context,
                  'Importar calibración',
                  'La calibración importada reemplazará la calibración actual.',
                )) {
                  await c.importCalibrations();
                }
              },
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
                'La calibración se conservará.',
              )) {
                c.clearJob();
              }
            }),
            AppUpdatesCard(controller: c.updates),
            _action(Icons.restart_alt, 'Restaurar configuración', () async {
              if (await confirm(
                context,
                'Restaurar configuración',
                'Se conservarán los trabajos y la calibración.',
              )) {
                c.resetSettings();
              }
            }),
          ],
        ),
        const SizedBox(height: 14),
        ExpansionTile(
          key: const PageStorageKey('advanced-settings'),
          title: const Text('Opciones avanzadas'),
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Modo simulación'),
              subtitle: const Text('Prueba la app sin conectar la máquina.'),
              value: s.simulation,
              onChanged: (v) => c.updateSettings(s.copyWith(simulation: v)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
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
              contentPadding: EdgeInsets.zero,
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
              // SelectableText owns a scroll position; do not reuse the tile's
              // PageStorage entry, which stores a bool instead of an offset.
              key: const PageStorageKey('settings-diagnostics'),
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

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({
    super.key,
    required this.appearance,
    required this.selected,
    required this.onTap,
  });

  final AppearanceTheme appearance;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final preview = microTheme(appearance);
    final (label, description) = switch (appearance) {
      AppearanceTheme.atelier => (
        'Atelier',
        'Marfil cálido y azul tinta para el taller.',
      ),
      AppearanceTheme.lagoon => (
        'Lagoon',
        'Azules frescos sobre superficies luminosas.',
      ),
      AppearanceTheme.porcelain => (
        'Porcelain',
        'Porcelana, azul grafito y acentos malva.',
      ),
      AppearanceTheme.amethyst => (
        'Amethyst',
        'Lavanda luminosa y violeta profundo.',
      ),
      AppearanceTheme.sunstone => (
        'Sunstone',
        'Arena dorada y ámbar, con detalles azul mineral.',
      ),
      AppearanceTheme.arctic => (
        'Arctic',
        'Azul cobalto y hielo, con acentos iris.',
      ),
      AppearanceTheme.midnight => (
        'Midnight',
        'Azul noche, acero y luz celeste. Tema oscuro.',
      ),
    };
    final borderRadius = BorderRadius.circular(12);
    return Semantics(
      label: '$label. $description',
      checked: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? colors.primaryContainer : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _AppearancePreview(theme: preview),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: selected
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(description, style: theme.textTheme.bodySmall),
                      ],
                    ),
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

/// A miniature surface and controls, using the same palette as the live theme.
class _AppearancePreview extends StatelessWidget {
  const _AppearancePreview({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;
    return Container(
      width: 52,
      height: 68,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurface,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: colors.outlineVariant),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors.secondary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
