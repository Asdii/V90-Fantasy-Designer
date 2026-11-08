import 'dart:convert';

/// Decoding is independent from networking so native and simulated inputs agree.
class Esp32Telemetry {
  const Esp32Telemetry({
    this.xMm,
    this.status,
    this.connected,
    this.deviceId,
    this.bootId,
    this.referenceId,
    this.referenceRevision,
    this.supportsXReference,
    this.requestId,
    this.accepted,
    this.error,
  });
  final double? xMm;
  final String? status;
  final bool? connected;
  final String? deviceId;
  final String? bootId;
  final String? referenceId;
  final int? referenceRevision;
  final bool? supportsXReference;
  final String? requestId;
  final bool? accepted;
  final String? error;
  bool get isReferenceAck => requestId != null;

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
    if (type != null &&
        type != 'position' &&
        type != 'status' &&
        type != 'reference_ack') {
      throw const FormatException('Unsupported telemetry type');
    }
    final rawX = value['x_mm'];
    final rawStatus = value['status'];
    final rawConnected = value['connected'];
    final deviceId = value['device_id'];
    final bootId = value['boot_id'];
    final referenceId = value['reference_id'];
    final revision = value['reference_revision'];
    final capabilities = value['capabilities'];
    final requestId = value['request_id'];
    final accepted = value['accepted'];
    if ((bootId != null && !validReferenceIdentifier(bootId)) ||
        (referenceId != null && !validReferenceIdentifier(referenceId)) ||
        (revision != null && (revision is! int || revision < 0)) ||
        (bootId != null && revision == null) ||
        (bootId == null && (referenceId != null || revision != null))) {
      throw const FormatException('Invalid X reference metadata');
    }
    if (capabilities != null &&
        (capabilities is! List || capabilities.any((c) => c is! String))) {
      throw const FormatException('Invalid capabilities');
    }
    if (type == 'reference_ack' &&
        (!validReferenceIdentifier(requestId) ||
            accepted is! bool ||
            bootId == null ||
            (accepted && (referenceId == null || rawX == null)))) {
      throw const FormatException('Invalid reference acknowledgement');
    }
    if (deviceId != null &&
        (deviceId is! String ||
            deviceId.isEmpty ||
            deviceId.length > 80 ||
            value['service'] != 'microfantasy-machine' ||
            value['api_version'] != 1)) {
      throw const FormatException('Invalid machine identity');
    }
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
        (type != 'reference_ack' &&
            rawX == null &&
            rawStatus == null &&
            rawConnected == null)) {
      throw const FormatException('Missing telemetry fields');
    }
    return Esp32Telemetry(
      xMm: (rawX as num?)?.toDouble(),
      status: rawStatus as String?,
      connected: rawConnected as bool?,
      deviceId: deviceId as String?,
      bootId: bootId as String?,
      referenceId: referenceId as String?,
      referenceRevision: revision as int?,
      supportsXReference: capabilities == null
          ? null
          : (capabilities as List).contains('set_x_reference'),
      requestId: type == 'reference_ack' ? requestId as String : null,
      accepted: type == 'reference_ack' ? accepted as bool : null,
      error: value['error'] is String ? value['error'] as String : null,
    );
  }
}

bool validReferenceIdentifier(Object? value) =>
    value is String && RegExp(r'^[A-Za-z0-9_.:-]{1,80}$').hasMatch(value);

void validateXReference(String bootId, String referenceId, double xMm) {
  if (!validReferenceIdentifier(bootId) ||
      !validReferenceIdentifier(referenceId) ||
      !xMm.isFinite ||
      xMm.abs() > 10000) {
    throw ArgumentError('Invalid physical X reference');
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
