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
  bool scanSupported = false, manualNetwork = true;
  List<MachineWifiNetwork> networks = const [];
  String? selectedNetwork;
  String message = '';
  String? connectedIp;

  Future<void> check() async {
    setState(() {
      busy = true;
      found = false;
      connectedIp = null;
      message = '';
    });
    try {
      final status = await widget.service.status();
      if (!mounted) return;
      setState(() {
        found = true;
        scanSupported = status.scanSupported;
        message = 'Máquina encontrada. Elige el Wi-Fi de tu casa.';
        if (status.connected) {
          connectedIp = status.ip;
          message = 'Wi-Fi guardado en la máquina.';
        }
      });
      if (status.connecting) {
        await waitForConnection();
      } else if (!status.connected && status.scanSupported) {
        await scanNetworks();
      }
    } on MachineSetupRequestException catch (error) {
      if (mounted) setState(() => message = error.message);
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

  Future<void> scanNetworks() async {
    setState(() {
      busy = true;
      message = 'Buscando redes desde la máquina…';
    });
    try {
      await widget.service.startScan();
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (mounted && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 750));
        if (!mounted) return;
        MachineWifiScan result;
        try {
          result = await widget.service.networks();
        } catch (_) {
          continue;
        } // The AP can briefly pause during a radio scan.
        if (!mounted) return;
        if (result.scanning) continue;
        setState(() {
          networks = result.networks;
          selectedNetwork = networks.any((n) => n.ssid == ssid.text)
              ? ssid.text
              : null;
          manualNetwork = networks.isEmpty;
          message = networks.isEmpty
              ? 'No se encontraron redes. Acerca la máquina al router y vuelve a buscar, o escribe el nombre de tu red.'
              : 'Elige tu Wi-Fi. La máquina selecciona automáticamente la señal compatible.';
        });
        return;
      }
      if (mounted) {
        setState(() {
          manualNetwork = true;
          message =
              'No se pudo completar la búsqueda. Puedes repetirla o escribir el nombre de tu red.';
        });
      }
    } on MachineSetupRequestException catch (error) {
      if (mounted) {
        setState(() {
          message = error.message;
          manualNetwork = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          manualNetwork = true;
          message =
              'No se pudo buscar. Comprueba que sigues en MicroFantasy-….';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> waitForConnection() async {
    // Firmware: scan + three 25 s attempts + backoff. Allow AP channel changes
    // without incorrectly treating a transient HTTP timeout as bad credentials.
    final deadline = DateTime.now().add(const Duration(seconds: 110));
    while (mounted && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      MachineSetupStatus status;
      try {
        status = await widget.service.status();
      } catch (_) {
        continue;
      }
      if (!mounted) return;
      if (status.error.isNotEmpty) {
        setState(() => message = status.errorMessage);
        return;
      }
      if (status.connected) {
        password.clear();
        setState(() {
          connectedIp = status.ip;
          message = 'Wi-Fi guardado en la máquina.';
        });
        return;
      }
      setState(() => message = status.progressMessage);
    }
    if (mounted) {
      setState(
        () => message =
            'No se pudo confirmar la conexión. Vuelve a comprobar la máquina; si ya volvió a la red de casa, usa Buscar máquina.',
      );
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
      await waitForConnection();
    } on MachineSetupRequestException catch (error) {
      if (mounted) setState(() => message = error.message);
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
              '1. Enciende la máquina.\n2. En los ajustes Wi-Fi del celular, conéctate a MicroFantasy-… con la contraseña fantasy123.\n3. Regresa aquí para elegir tu red de casa. Solo necesitas hacerlo la primera vez o al cambiar de red.',
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
              if (scanSupported && networks.isNotEmpty && !manualNetwork)
                DropdownButtonFormField<String>(
                  key: ValueKey(networks),
                  initialValue: selectedNetwork,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Wi-Fi de casa'),
                  hint: const Text('Elige tu red'),
                  items: networks
                      .map(
                        (n) => DropdownMenuItem(
                          value: n.ssid,
                          child: Text(n.ssid, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          selectedNetwork = value;
                          ssid.text = value ?? '';
                          password.clear();
                        }),
                ),
              if (manualNetwork)
                TextField(
                  controller: ssid,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Wi-Fi de casa',
                  ),
                  autocorrect: false,
                  enabled: !busy,
                ),
              if (scanSupported)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: busy ? null : scanNetworks,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Buscar redes'),
                    ),
                    if (networks.isNotEmpty)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                manualNetwork = !manualNetwork;
                                if (!manualNetwork) {
                                  selectedNetwork =
                                      networks.any((n) => n.ssid == ssid.text)
                                      ? ssid.text
                                      : null;
                                }
                              }),
                        child: Text(
                          manualNetwork
                              ? 'Elegir de la lista'
                              : 'Escribir nombre',
                        ),
                      ),
                  ],
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
                onPressed: busy || (!manualNetwork && selectedNetwork == null)
                    ? null
                    : save,
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
