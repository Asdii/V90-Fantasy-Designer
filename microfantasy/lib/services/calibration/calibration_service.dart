import '../../models/calibration_profile.dart';
import '../../models/validation.dart';

/// Piecewise linear calibration over the circle, including the 360/0 seam.
class CalibrationService {
  const CalibrationService();

  static double normalizeAngle(double angleR) => normalizeDegrees(angleR);

  /// Interpolated offset in mm: measured X at [angleR] minus reference X.
  ///
  /// One point yields a constant offset. An empty profile is an unfinished
  /// calibration and throws [StateError], rather than returning a false zero.
  double offsetAt(CalibrationProfile profile, double angleR) {
    final double angle = normalizeAngle(angleR);
    final List<CalibrationPoint> points = profile.points;
    if (points.isEmpty) {
      throw StateError('The calibration profile has no measurements.');
    }
    if (points.length == 1) {
      return points.single.x - profile.referenceX;
    }
    for (final CalibrationPoint point in points) {
      if (point.angleR == angle) {
        return point.x - profile.referenceX;
      }
    }

    int upperIndex = points.indexWhere(
      (CalibrationPoint point) => point.angleR > angle,
    );
    if (upperIndex < 0) {
      upperIndex = 0;
    }
    final CalibrationPoint upper = points[upperIndex];
    final CalibrationPoint lower =
        points[(upperIndex - 1 + points.length) % points.length];
    final double upperAngle = upperIndex == 0
        ? upper.angleR + 360
        : upper.angleR;
    final double queryAngle = angle < lower.angleR ? angle + 360 : angle;
    final double fraction =
        (queryAngle - lower.angleR) / (upperAngle - lower.angleR);
    final double lowerOffset = lower.x - profile.referenceX;
    final double upperOffset = upper.x - profile.referenceX;
    // Weighted endpoints avoid overflowing (upperOffset - lowerOffset) for
    // large finite offsets with opposite signs.
    return finiteNumber(
      lowerOffset * (1 - fraction) + upperOffset * fraction,
      'interpolated calibration offset',
    );
  }

  /// Corrects a nominal X in mm. Raw sensor inversion belongs to the controller
  /// and is applied before calibration; target coordinates are never inverted.
  double correctedX({
    required CalibrationProfile profile,
    required double angleR,
    required double x,
  }) {
    finiteNumber(x, 'x');
    return finiteNumber(x + offsetAt(profile, angleR), 'corrected X');
  }

  /// Wizard target angles. 360 is omitted because it duplicates zero.
  List<double> sampleAngles(int interval) {
    integer(interval, 'angleInterval', min: 1, max: 360);
    return List<double>.unmodifiable(<double>[
      for (int angle = 0; angle < 360; angle += interval) angle.toDouble(),
    ]);
  }
}
