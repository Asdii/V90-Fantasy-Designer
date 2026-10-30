import 'package:flutter/material.dart';
import '../app/update_controller.dart';
import 'common.dart';

class AppUpdateBanner extends StatelessWidget {
  const AppUpdateBanner({super.key, required this.controller});
  final UpdateController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller;
      if (!c.showBanner) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.fromLTRB(18, 10, 18, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xffe1f3fb),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text('Nueva versión ${c.available!.versionName}'),
            TextButton(
              onPressed: c.opening ? null : c.download,
              child: const Text('Actualizar'),
            ),
            TextButton(onPressed: c.later, child: const Text('Más tarde')),
          ],
        ),
      );
    },
  );
}

class AppUpdatesCard extends StatelessWidget {
  const AppUpdatesCard({super.key, required this.controller});
  final UpdateController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller;
      return Section(
        title: 'Actualizaciones',
        children: [
          if (!c.supported)
            const Text(
              'Las actualizaciones por APK están disponibles en Android.',
            )
          else ...[
            if (c.installed != null)
              Text('Versión instalada: ${c.installed!.versionName}'),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Buscar automáticamente'),
              subtitle: const Text('Una vez al día, al abrir la app.'),
              value: c.automatic,
              onChanged: c.setAutomatic,
            ),
            Text(c.status),
            if (c.available != null && c.available!.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(c.available!.notes),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: c.checking ? null : () => c.check(manual: true),
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    c.checking ? 'Buscando…' : 'Buscar actualizaciones',
                  ),
                ),
                if (c.available != null)
                  FilledButton.icon(
                    onPressed: c.opening ? null : c.download,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Actualizar'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Se abre la descarga oficial en tu navegador. Abre el APK y confirma Actualizar; tus trabajos y calibraciones se conservan.',
            ),
          ],
        ],
      );
    },
  );
}
