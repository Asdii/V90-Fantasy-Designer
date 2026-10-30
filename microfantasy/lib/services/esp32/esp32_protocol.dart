import 'dart:convert';

/// Decoding is independent from networking so native and simulated inputs agree.
class Esp32Telemetry {
  const Esp32Telemetry({this.xMm, this.status, this.connected});
  final double? xMm;
  final String? status;
  final bool? connected;

  factory Esp32Telemetry.decode(Object? message, {int maxBytes = 16 * 1024}) {
    final String text;
    if (message is String) {
      if (message.length > maxBytes || utf8.encode(message).length > maxBytes) {
        throw const FormatException('Telemetry exceeds the size limit');
      }
      text = message;
    } else if (message is List<int>) {
      if (message.length > maxBytes) {
        throw const FormatException('Telemetry exceeds the size limit');
      }
      text = utf8.decode(message);
    } else {
      throw const FormatException('Telemetry must be UTF-8 JSON');
    }
    final value = jsonDecode(text);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Telemetry must be a JSON object');
    }
    final type = value['type'];
    if (type != null && type != 'position' && type != 'status') {
      throw const FormatException('Unsupported telemetry type');
    }
    final rawX = value['x_mm'];
    final rawStatus = value['status'];
    final rawConnected = value['connected'];
    if (value.containsKey('connected') && rawConnected is! bool) {
      throw const FormatException('connected must be a boolean');
    }
    if (value.containsKey('x_mm') && (rawX is! num || !rawX.isFinite)) {
      throw const FormatException('x_mm must be a finite number');
    }
    if (value.containsKey('status') &&
        (rawStatus is! String || rawStatus.isEmpty || rawStatus.length > 128)) {
      throw const FormatException(
        'status must be a nonempty string of <=128 characters',
      );
    }
    if ((type == 'position' && rawX == null) ||
        (type == 'status' && rawStatus == null && rawConnected == null) ||
        (rawX == null && rawStatus == null && rawConnected == null)) {
      throw const FormatException('Missing telemetry fields');
    }
    return Esp32Telemetry(
      xMm: (rawX as num?)?.toDouble(),
      status: rawStatus as String?,
      connected: rawConnected as bool?,
    );
  }
}

void validateEsp32Endpoint(Uri endpoint) {
  if (!['ws', 'wss'].contains(endpoint.scheme) ||
      endpoint.host.isEmpty ||
      endpoint.userInfo.isNotEmpty ||
      endpoint.hasFragment ||
      endpoint.port <= 0 ||
      endpoint.port > 65535) {
    throw ArgumentError.value(
      endpoint,
      'endpoint',
      'Expected a ws:// or wss:// endpoint',
    );
  }
}
