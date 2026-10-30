import 'dart:convert';
import 'dart:io';
import 'provisioning_service.dart';

class HttpMachineProvisioningService implements MachineProvisioningService {
  HttpMachineProvisioningService({
    Uri? endpoint,
    this.timeout = const Duration(seconds: 5),
  }) : endpoint = endpoint ?? Uri.parse('http://192.168.4.1/api/v1/setup');
  final Uri endpoint;
  final Duration timeout;

  Future<Map<String, dynamic>> _request(String method, [String? body]) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      return await (() async {
        final request = await client.openUrl(method, endpoint);
        request.followRedirects =
            false; // Never forward home credentials elsewhere.
        if (body != null) {
          request.headers.contentType = ContentType.json;
          request.write(body);
        }
        final response = await request.close();
        if (response.statusCode != (method == 'POST' ? 202 : 200)) {
          throw const HttpException(
            'La máquina no aceptó la configuración. Revisa la conexión y vuelve a intentar.',
          );
        }
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > 4096) {
            throw const FormatException('Respuesta demasiado grande');
          }
        }
        final data = jsonDecode(utf8.decode(bytes));
        if (data is! Map<String, dynamic>) {
          throw const FormatException('Respuesta no válida');
        }
        return data;
      })().timeout(timeout);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<MachineSetupStatus> status() async =>
      MachineSetupStatus.fromJson(await _request('GET'));

  @override
  Future<void> configure(String ssid, String password) async {
    final data = await _request('POST', setupPayload(ssid, password));
    if (data['accepted'] != true) {
      throw const FormatException('Configuración no aceptada');
    }
  }
}
