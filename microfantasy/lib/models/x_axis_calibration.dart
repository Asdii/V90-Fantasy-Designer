import 'validation.dart';

/// Physical X frame, independent of the encoder's temporary power-on counter.
/// Stops need not be equidistant from the manually established table center.
class AxisCalibration {
  AxisCalibration({
    required this.deviceId,
    required this.referenceId,
    this.negativeMm,
    this.positiveMm,
  }) {
    for (final id in [deviceId, referenceId]) {
      if (!RegExp(r'^[A-Za-z0-9_.:-]{1,80}$').hasMatch(id)) {
        throw const FormatException('Invalid axis calibration identity');
      }
    }
    if (negativeMm != null &&
        (!negativeMm!.isFinite || negativeMm! >= 0 || negativeMm! < -10000)) {
      throw const FormatException(
        'La lectura de este extremo debe quedar bajo 0 mm.',
      );
    }
    if (positiveMm != null &&
        (!positiveMm!.isFinite || positiveMm! <= 0 || positiveMm! > 10000)) {
      throw const FormatException(
        'La lectura de este extremo debe quedar sobre 0 mm.',
      );
    }
  }

  final String deviceId;
  final String referenceId;
  final double? negativeMm;
  final double? positiveMm;
  bool get isComplete => negativeMm != null && positiveMm != null;
  double? get travelMm => isComplete ? positiveMm! - negativeMm! : null;

  AxisCalibration withStop({required bool positive, required double value}) =>
      AxisCalibration(
        deviceId: deviceId,
        referenceId: referenceId,
        negativeMm: positive ? negativeMm : value,
        positiveMm: positive ? value : positiveMm,
      );

  AxisCalibration inverted() => AxisCalibration(
    deviceId: deviceId,
    referenceId: referenceId,
    negativeMm: positiveMm == null ? null : -positiveMm!,
    positiveMm: negativeMm == null ? null : -negativeMm!,
  );

  Map<String, Object?> toJson() => {
    'deviceId': deviceId,
    'referenceId': referenceId,
    'negativeMm': negativeMm,
    'positiveMm': positiveMm,
  };

  factory AxisCalibration.fromJson(Map<String, Object?> json) =>
      AxisCalibration(
        deviceId: nonEmptyString(json['deviceId'], 'deviceId'),
        referenceId: nonEmptyString(json['referenceId'], 'referenceId'),
        negativeMm: json['negativeMm'] == null
            ? null
            : finiteNumber(json['negativeMm'], 'negativeMm'),
        positiveMm: json['positiveMm'] == null
            ? null
            : finiteNumber(json['positiveMm'], 'positiveMm'),
      );
}
