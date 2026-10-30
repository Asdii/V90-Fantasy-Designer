import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/esp32/provisioning_service.dart';

class MachineSetupDialog extends StatefulWidget {
  const MachineSetupDialog({super.key, required this.service});
  final MachineProvisioningService service;
  @override
  State<MachineSetupDialog> createState() => _MachineSetupDialogState();
}

class _MachineSetupDialogState extends State<MachineSetupDialog> {
  final ssid = TextEditingController();
  final password = TextEditingController();
  bool busy = false, found = false;
  String message = '';
  String? connectedIp;

  Future<void> check() async {
    setState(() {
      busy = true;
      message = '';
    });
    try {
      final status = await widget.service.status();
      if (!mounted) return;
      setState(() {
        found = true;
        message =
            'Máquina encontrada. Introduce el Wi-Fi de tu casa (2.4 GHz).';
        if (status.connected) connectedIp = status.ip;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'No se encontró la máquina. Conéctate a MicroFantasy-… y permanece en esa red aunque no tenga Internet.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    try {
      setupPayload(ssid.text, password.text);
    } on FormatException catch (error) {
      setState(() => message = error.message);
      return;
    }
    setState(() {
      busy = true;
      message = 'Conectando la máquina al Wi-Fi…';
    });
    try {
      await widget.service.configure(ssid.text, password.text);
      password.clear();
      final deadline = DateTime.now().add(const Duration(seconds: 40));
      while (mounted && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        MachineSetupStatus status;
        try {
          status = await widget.service.status();
        } catch (_) {
          continue;
        } // AP may briefly change channel when STA joins.
        if (!mounted) return;
        if (status.error.isNotEmpty) {
          setState(
            () => message = status.error == 'storage_error'
                ? 'No se pudo guardar en la máquina. Reiníciala y vuelve a intentar.'
                : 'No se pudo conectar. Revisa la contraseña y que la red sea de 2.4 GHz.',
          );
          return;
        }
        if (status.connected) {
          setState(() {
            connectedIp = status.ip;
            message = 'Wi-Fi guardado en la máquina.';
          });
          return;
        }
      }
      if (mounted) {
        setState(
          () => message =
              'No se pudo confirmar la conexión. Vuelve a comprobar la máquina; si ya volvió a la red de casa, usa Buscar máquina.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'No se pudo enviar. Comprueba que sigues en la red MicroFantasy-… y vuelve a intentar.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    ssid.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Conectar tu máquina'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '1. Enciende la máquina.\n2. En los ajustes Wi-Fi del celular, conéctate a MicroFantasy-… con la clave de configuración de tu dispositivo.\n3. Regresa aquí. Este paso solo es necesario la primera vez o al cambiar de red.',
            ),
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
              TextButton.icon(
                onPressed: () async {
                  try {
                    await const MethodChannel(
                      'app.microfantasy/network',
                    ).invokeMethod<void>('openWifiSettings');
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => message =
                            'Abre los ajustes Wi-Fi del celular manualmente.',
                      );
                    }
                  }
                },
                icon: const Icon(Icons.wifi),
                label: const Text('Abrir ajustes Wi-Fi'),
              ),
            OutlinedButton(
              onPressed: busy ? null : check,
              child: const Text('Ya estoy conectado: comprobar'),
            ),
            if (found && connectedIp == null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: ssid,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Wi-Fi de casa',
                ),
                autocorrect: false,
                enabled: !busy,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                decoration: const InputDecoration(
                  labelText: 'Contraseña del Wi-Fi',
                ),
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !busy,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy ? null : save,
                child: const Text('Guardar Wi-Fi en la máquina'),
              ),
            ],
            if (busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              ),
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(message),
              ),
            if (connectedIp != null)
              Text(
                '\n4. Vuelve al Wi-Fi de casa en tu celular y toca Terminar.\nDirección de la máquina: $connectedIp',
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
      if (connectedIp != null)
        FilledButton(
          onPressed: () => Navigator.pop(context, connectedIp),
          child: const Text('Terminar'),
        ),
    ],
  );
}
