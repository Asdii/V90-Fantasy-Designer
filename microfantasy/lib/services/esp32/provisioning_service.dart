import 'dart:convert';

export 'provisioning_service_stub.dart'
    if (dart.library.io) 'provisioning_service_io.dart';

class MachineSetupStatus {
  const MachineSetupStatus({
    required this.connected,
    required this.connecting,
    required this.ip,
    required this.error,
    this.scanSupported = false,
    this.phase = '',
    this.attempt = 0,
    this.maxAttempts = 3,
    this.reasonCode = 0,
  });
  final bool connected;
  final bool connecting;
  final String ip;
  final String error;
  final bool scanSupported;
  final String phase;
  final int attempt;
  final int maxAttempts;
  final int reasonCode;

  String get progressMessage => switch (phase) {
    'scanning' => 'Buscando tu red de casa…',
    'retrying' => 'Reintentando la conexión automáticamente…',
    'getting_address' =>
      'Conectada al Wi-Fi. Esperando la dirección de la máquina…',
    _ =>
      attempt > 1
          ? 'Conectando al Wi-Fi… Intento $attempt de $maxAttempts.'
          : 'Conectando la máquina al Wi-Fi…',
  };

  String get errorMessage => switch (error) {
    'storage_error' =>
      'No se pudo guardar en la máquina. Reiníciala y vuelve a intentar.',
    'network_not_found' =>
      'La máquina no encuentra esa red. Acércala al router y vuelve a buscar redes.',
    'authentication_failed' =>
      'La red no aceptó la conexión. Comprueba la contraseña y vuelve a intentar.',
    'association_failed' =>
      'La red rechazó la conexión de la máquina después de varios intentos. Puedes seguir usándola en MicroFantasy-….',
    'address_timeout' =>
      'La máquina se conectó al Wi-Fi, pero no recibió una dirección. Vuelve a intentar.',
    'signal_lost' =>
      'Se perdió la señal del Wi-Fi. Acerca la máquina al router y vuelve a intentar.',
    _ =>
      'La máquina no pudo completar la conexión. Puedes reintentar o seguir usándola en MicroFantasy-….',
  };

  factory MachineSetupStatus.fromJson(Map<String, dynamic> data) {
    if (data['device'] != 'MicroFantasy' ||
        data['schemaVersion'] != 1 ||
        data['connected'] is! bool ||
        data['connecting'] is! bool ||
        data['ip'] is! String ||
        data['error'] is! String) {
      throw const FormatException('Respuesta de máquina no compatible');
    }
    if ((data.containsKey('scan_supported') &&
            data['scan_supported'] is! bool) ||
        (data.containsKey('phase') && data['phase'] is! String) ||
        ['attempt', 'max_attempts', 'reason_code'].any(
          (key) =>
              data.containsKey(key) &&
              (data[key] is! int ||
                  (data[key] as int) < 0 ||
                  (data[key] as int) > 1000),
        )) {
      throw const FormatException('Progreso Wi-Fi no válido');
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
      scanSupported: data['scan_supported'] as bool? ?? false,
      phase: data['phase'] as String? ?? '',
      attempt: data['attempt'] as int? ?? 0,
      maxAttempts: data['max_attempts'] as int? ?? 3,
      reasonCode: data['reason_code'] as int? ?? 0,
    );
  }
}

class MachineWifiNetwork {
  const MachineWifiNetwork({
    required this.ssid,
    required this.rssi,
    required this.secured,
  });
  final String ssid;
  final int rssi;
  final bool secured;
}

class MachineWifiScan {
  const MachineWifiScan({
    required this.scanning,
    this.networks = const [],
    this.error = '',
  });
  final bool scanning;
  final List<MachineWifiNetwork> networks;
  final String error;

  factory MachineWifiScan.fromJson(Map<String, dynamic> data) {
    final items = data['networks'];
    if (data['device'] != 'MicroFantasy' ||
        data['schemaVersion'] != 1 ||
        data['scanning'] is! bool ||
        data['error'] is! String ||
        items is! List ||
        items.length > 24) {
      throw const FormatException('Lista de redes no válida');
    }
    final networks = <MachineWifiNetwork>[];
    for (final item in items) {
      if (item is! Map<String, dynamic> ||
          item['ssid'] is! String ||
          (item['ssid'] as String).isEmpty ||
          utf8.encode(item['ssid'] as String).length > 32 ||
          (item['ssid'] as String).contains('\u0000') ||
          item['rssi'] is! int ||
          (item['rssi'] as int) < -127 ||
          (item['rssi'] as int) > 0 ||
          item['secured'] is! bool) {
        throw const FormatException('Red Wi-Fi no válida');
      }
      networks.add(
        MachineWifiNetwork(
          ssid: item['ssid'] as String,
          rssi: item['rssi'] as int,
          secured: item['secured'] as bool,
        ),
      );
    }
    return MachineWifiScan(
      scanning: data['scanning'] as bool,
      networks: List.unmodifiable(networks),
      error: data['error'] as String,
    );
  }
}

abstract interface class MachineProvisioningService {
  Future<MachineSetupStatus> status();
  Future<void> configure(String ssid, String password);
  Future<void> startScan();
  Future<MachineWifiScan> networks();
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
