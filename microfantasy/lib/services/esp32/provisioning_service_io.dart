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
          // Arduino-ESP32 2.0.17 WebServer reads bodies by Content-Length;
          // it does not decode Dart's default chunked request encoding.
          // Count UTF-8 bytes, not characters, for SSIDs/passwords with accents.
          final payload = utf8.encode(body);
          request.headers.contentType = ContentType.json;
          request.contentLength = payload.length;
          request.add(payload);
        }
        final response = await request.close();
        if (response.statusCode != (method == 'POST' ? 202 : 200)) {
          throw MachineSetupRequestException(response.statusCode);
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
