import 'dart:math' as math;
import 'validation.dart';

class HelperPoint {
  HelperPoint(this.u, this.v) {
    finiteNumber(u, 'u');
    finiteNumber(v, 'v');
  }
  final double u, v;
  factory HelperPoint.fromJson(Map<String, Object?> json) =>
      HelperPoint(finiteNumber(json['u'], 'u'), finiteNumber(json['v'], 'v'));
  Map<String, Object?> toJson() => {'u': u, 'v': v};
}

class HelperSegment {
  HelperSegment(this.start, this.end);
  final HelperPoint start, end;
  double get length =>
      math.sqrt(math.pow(end.u - start.u, 2) + math.pow(end.v - start.v, 2));
  double get signedDistance =>
      (start.u * (end.v - start.v) - start.v * (end.u - start.u)) / length;
  double get angle =>
      (math.atan2(end.v - start.v, end.u - start.u) * 180 / math.pi + 360) %
      360;
  factory HelperSegment.fromJson(Map<String, Object?> json) => HelperSegment(
    HelperPoint.fromJson(jsonObject(json['start'], 'start')),
    HelperPoint.fromJson(jsonObject(json['end'], 'end')),
  );
  Map<String, Object?> toJson() => {
    'start': start.toJson(),
    'end': end.toJson(),
  };
}

class HelperInstruction {
  HelperInstruction.fromJson(Map<String, Object?> json)
    : index = integer(json['index'], 'helper.index', min: 0),
      operationId = nonEmptyString(json['operationId'], 'operationId'),
      operationNumber = integer(
        json['operationNumber'],
        'operationNumber',
        min: 1,
      ),
      distanceMm = nonNegativeNumber(
        json['distanceFromCenterMm'],
        'distanceFromCenterMm',
      ),
      signedDistanceMm = finiteNumber(
        json['signedDistanceMm'],
        'signedDistanceMm',
      ),
      grooveWidthMm = nonNegativeNumber(json['grooveWidthMm'], 'grooveWidthMm'),
      segment = HelperSegment.fromJson(jsonObject(json['segment'], 'segment')),
      visibleSegments = List.unmodifiable(
        jsonList(
          json['visibleSegments'],
          'visibleSegments',
        ).map((v) => HelperSegment.fromJson(jsonObject(v, 'visibleSegment'))),
      ) {
    if (segment.length <= 1e-12 ||
        !closeHelperNumber(segment.signedDistance, signedDistanceMm) ||
        !closeHelperNumber(distanceMm, signedDistanceMm.abs())) {
      throw const FormatException(
        'Cut Helper distance does not match its geometry.',
      );
    }
  }
  final int index, operationNumber;
  final String operationId;
  final double distanceMm, signedDistanceMm, grooveWidthMm;
  final HelperSegment segment;
  final List<HelperSegment> visibleSegments;
  Map<String, Object?> toJson() => {
    'index': index,
    'operationId': operationId,
    'operationNumber': operationNumber,
    'distanceFromCenterMm': distanceMm,
    'signedDistanceMm': signedDistanceMm,
    'grooveWidthMm': grooveWidthMm,
    'segment': segment.toJson(),
    'visibleSegments': visibleSegments.map((s) => s.toJson()).toList(),
  };
}

/// V90's common reference frame and drawing dimensions. Never recentered on the phone.
class CutHelperData {
  CutHelperData.fromJson(Map<String, Object?> json)
    : referenceFacetId = integer(
        json['referenceFacetId'],
        'referenceFacetId',
        min: 0,
      ),
      boundary = List.unmodifiable(
        jsonList(
          json['boundary'],
          'boundary',
        ).map((p) => HelperPoint.fromJson(jsonObject(p, 'boundaryPoint'))),
      ),
      steps = List.unmodifiable(
        jsonList(
          json['steps'],
          'helper.steps',
        ).map((s) => HelperInstruction.fromJson(jsonObject(s, 'helper.step'))),
      ),
      machineCenterXmm = finiteNumber(
        json['machineCenterXmm'],
        'machineCenterXmm',
      ) {
    if (json['version'] != 1 ||
        json['coordinateSystem'] != 'facet-local-mm-y-up') {
      throw const FormatException('Unsupported V90 Cut Helper format.');
    }
    final viewport = jsonObject(json['viewport'], 'viewport');
    extent = finiteNumber(viewport['extent'], 'extent');
    wheelRadius = finiteNumber(viewport['wheelRadius'], 'wheelRadius');
    hairline = finiteNumber(viewport['hairline'], 'hairline');
    final view = jsonObject(json['initialView'], 'initialView');
    initialStepIndex = integer(
      view['stepIndex'],
      'initialView.stepIndex',
      min: 0,
    );
    direction = nonEmptyString(view['direction'], 'direction');
    orientation = nonEmptyString(view['orientation'], 'orientation');
    if (boundary.length < 3 ||
        steps.isEmpty ||
        initialStepIndex >= steps.length ||
        extent <= wheelRadius ||
        wheelRadius <= 0 ||
        hairline <= 0 ||
        hairline >= extent ||
        !['horizontal', 'vertical'].contains(direction) ||
        !['cut', 'zero'].contains(orientation)) {
      throw const FormatException('Invalid Cut Helper viewport or view.');
    }
    for (final p in [
      ...boundary,
      for (final s in steps)
        for (final line in s.visibleSegments) ...[line.start, line.end],
    ]) {
      if (p.u.abs() > extent || p.v.abs() > extent) {
        throw const FormatException(
          'Cut Helper point is outside its viewport.',
        );
      }
    }
  }
  final int referenceFacetId;
  final List<HelperPoint> boundary;
  final List<HelperInstruction> steps;
  final double machineCenterXmm;
  late final double extent, wheelRadius, hairline;
  late final int initialStepIndex;
  late final String direction, orientation;
  Map<String, Object?> toJson() => {
    'version': 1,
    'coordinateSystem': 'facet-local-mm-y-up',
    'referenceFacetId': referenceFacetId,
    'boundary': boundary.map((p) => p.toJson()).toList(),
    'viewport': {
      'extent': extent,
      'wheelRadius': wheelRadius,
      'hairline': hairline,
    },
    'initialView': {
      'stepIndex': initialStepIndex,
      'direction': direction,
      'orientation': orientation,
    },
    'machineCenterXmm': machineCenterXmm,
    'steps': steps.map((s) => s.toJson()).toList(),
  };
}

bool closeHelperNumber(double a, double b) =>
    (a - b).abs() <= 1e-8 * math.max(1, math.max(a.abs(), b.abs()));
