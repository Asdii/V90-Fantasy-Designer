import 'validation.dart';

/// An absolute measured X (mm) at a canonical rotation angle in [0, 360).
class CalibrationPoint {
  factory CalibrationPoint({required double angleR, required double x}) {
    finiteNumber(x, 'calibration.x');
    return CalibrationPoint._(normalizeDegrees(angleR), x);
  }

  const CalibrationPoint._(this.angleR, this.x);

  factory CalibrationPoint.fromJson(Map<String, Object?> json) =>
      CalibrationPoint(
        angleR: finiteNumber(json['angleR'], 'calibration.angleR'),
        x: finiteNumber(json['x'], 'calibration.x'),
      );

  final double angleR;
  final double x;

  Map<String, Object?> toJson() => <String, Object?>{'angleR': angleR, 'x': x};
}

/// Samples are sorted by normalized angle and defensively copied.
///
/// Empty profiles are allowed while collecting calibration measurements, but
/// cannot be used to correct machine coordinates. Duplicate circular angles
/// (for example 0 and 360) are rejected rather than silently overwriting data.
class CalibrationProfile {
  factory CalibrationProfile({
    required String id,
    required String name,
    required double referenceX,
    required List<CalibrationPoint> points,
  }) {
    nonEmptyString(id, 'profile.id');
    nonEmptyString(name, 'profile.name');
    finiteNumber(referenceX, 'profile.referenceX');
    final List<CalibrationPoint> sorted = List<CalibrationPoint>.of(points)
      ..sort(
        (CalibrationPoint a, CalibrationPoint b) =>
            a.angleR.compareTo(b.angleR),
      );
    for (int i = 0; i < sorted.length; i++) {
      finiteNumber(sorted[i].x - referenceX, 'calibration offset');
      if (i > 0 && sorted[i].angleR == sorted[i - 1].angleR) {
        throw FormatException(
          'Duplicate calibration angle: ${sorted[i].angleR}.',
        );
      }
    }
    return CalibrationProfile._(
      id,
      name,
      referenceX,
      List<CalibrationPoint>.unmodifiable(sorted),
    );
  }

  const CalibrationProfile._(this.id, this.name, this.referenceX, this.points);

  factory CalibrationProfile.fromJson(Map<String, Object?> json) =>
      CalibrationProfile(
        id: nonEmptyString(json['id'], 'profile.id'),
        name: nonEmptyString(json['name'], 'profile.name'),
        referenceX: finiteNumber(json['referenceX'], 'profile.referenceX'),
        points: jsonList(json['points'], 'profile.points')
            .map(
              (Object? value) =>
                  CalibrationPoint.fromJson(jsonObject(value, 'profile.point')),
            )
            .toList(),
      );

  final String id;
  final String name;
  final double referenceX;
  final List<CalibrationPoint> points;

  bool get isCalibrated => points.isNotEmpty;

  CalibrationProfile copyWith({
    String? name,
    double? referenceX,
    List<CalibrationPoint>? points,
  }) => CalibrationProfile(
    id: id,
    name: name ?? this.name,
    referenceX: referenceX ?? this.referenceX,
    points: points ?? this.points,
  );

  /// Replaces an existing circular angle or inserts a new measurement.
  CalibrationProfile withPoint(CalibrationPoint point) => copyWith(
    points: <CalibrationPoint>[
      ...points.where(
        (CalibrationPoint existing) => existing.angleR != point.angleR,
      ),
      point,
    ],
  );

  CalibrationProfile withoutPoint(double angleR) {
    final double normalized = normalizeDegrees(angleR);
    return copyWith(
      points: points
          .where((CalibrationPoint point) => point.angleR != normalized)
          .toList(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'referenceX': referenceX,
    'points': points.map((CalibrationPoint point) => point.toJson()).toList(),
  };
}
