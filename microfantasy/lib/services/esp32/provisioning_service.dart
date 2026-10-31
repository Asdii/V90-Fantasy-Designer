import 'dart:convert';

export 'provisioning_service_stub.dart'
    if (dart.library.io) 'provisioning_service_io.dart';

class MachineSetupStatus {
  const MachineSetupStatus({
    required this.connected,
    required this.connecting,
    required this.ip,
    required this.error,
  });
  final bool connected;
  final bool connecting;
  final String ip;
  final String error;

  factory MachineSetupStatus.fromJson(Map<String, dynamic> data) {
    if (data['device'] != 'MicroFantasy' ||
        data['schemaVersion'] != 1 ||
        data['connected'] is! bool ||
        data['connecting'] is! bool ||
        data['ip'] is! String ||
        data['error'] is! String) {
      throw const FormatException('Respuesta de máquina no compatible');
    }
    final ip = data['ip'] as String;
    final parts = ip.split('.');
    if (parts.length != 4 ||
        parts.any(
          (p) =>
              int.tryParse(p) == null || int.parse(p) < 0 || int.parse(p) > 255,
        ) ||
        (data['connected'] == true && ip == '0.0.0.0')) {
      throw const FormatException('Dirección de máquina no válida');
    }
    return MachineSetupStatus(
      connected: data['connected'] as bool,
      connecting: data['connecting'] as bool,
      ip: ip,
      error: data['error'] as String,
    );
  }
}

abstract interface class MachineProvisioningService {
  Future<MachineSetupStatus> status();
  Future<void> configure(String ssid, String password);
}

/// A device rejection is distinct from losing the Wi-Fi connection.
/// Never include the credential payload or an untrusted response body in errors.
class MachineSetupRequestException implements Exception {
  const MachineSetupRequestException(this.statusCode);
  final int statusCode;

  String get message => switch (statusCode) {
    400 =>
      'La máquina rechazó los datos Wi-Fi. Revisa el nombre y la contraseña.',
    403 =>
      'La configuración solo está disponible en la red MicroFantasy-…. Conéctate a esa red y vuelve a comprobar.',
    409 =>
      'La máquina ya está intentando conectarse. Espera unos segundos y vuelve a comprobar.',
    _ =>
      'La máquina rechazó la solicitud (HTTP $statusCode). Vuelve a intentar.',
  };

  @override
  String toString() => 'MachineSetupRequestException($statusCode): $message';
}

String setupPayload(String ssid, String password) {
  final name = utf8.encode(ssid);
  final key = utf8.encode(password);
  if (name.isEmpty ||
      name.length > 32 ||
      ssid.contains('\u0000') ||
      password.contains('\u0000') ||
      (key.isNotEmpty && (key.length < 8 || key.length > 63))) {
    throw const FormatException(
      'Revisa el nombre Wi-Fi y la contraseña (8–63 bytes, o vacía para red abierta).',
    );
  }
  return jsonEncode({'ssid': ssid, 'password': password});
}
