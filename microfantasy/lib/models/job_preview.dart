import 'validation.dart';

/// Dimensionless preview coordinates in the closed interval [0, 1].
class PreviewPoint {
  factory PreviewPoint({required double x, required double y}) {
    boundedNumber(x, 'preview.x', 0, 1);
    boundedNumber(y, 'preview.y', 0, 1);
    return PreviewPoint._(x, y);
  }

  const PreviewPoint._(this.x, this.y);

  factory PreviewPoint.fromJson(Map<String, Object?> json) => PreviewPoint(
    x: finiteNumber(json['x'], 'preview.x'),
    y: finiteNumber(json['y'], 'preview.y'),
  );

  final double x;
  final double y;

  Map<String, Object?> toJson() => <String, Object?>{'x': x, 'y': y};
}

class PreviewSegment {
  factory PreviewSegment({
    required PreviewPoint start,
    required PreviewPoint end,
    int? stepIndex,
  }) {
    if (stepIndex != null) {
      integer(stepIndex, 'preview.stepIndex', min: 0);
    }
    return PreviewSegment._(start, end, stepIndex);
  }

  const PreviewSegment._(this.start, this.end, this.stepIndex);

  factory PreviewSegment.fromJson(Map<String, Object?> json) => PreviewSegment(
    start: PreviewPoint.fromJson(jsonObject(json['start'], 'preview.start')),
    end: PreviewPoint.fromJson(jsonObject(json['end'], 'preview.end')),
    stepIndex: json['stepIndex'] == null
        ? null
        : integer(json['stepIndex'], 'preview.stepIndex', min: 0),
  );

  final PreviewPoint start;
  final PreviewPoint end;

  /// Optional link to a job step's index, not its position in the steps list.
  final int? stepIndex;

  Map<String, Object?> toJson() => <String, Object?>{
    'start': start.toJson(),
    'end': end.toJson(),
    if (stepIndex != null) 'stepIndex': stepIndex,
  };
}

/// A preview is visual metadata; it never supplies machine coordinates.
class JobPreview {
  JobPreview({required List<PreviewSegment> segments})
    : segments = List<PreviewSegment>.unmodifiable(segments);

  factory JobPreview.fromJson(Map<String, Object?> json) => JobPreview(
    segments: jsonList(json['segments'], 'preview.segments')
        .map(
          (Object? value) =>
              PreviewSegment.fromJson(jsonObject(value, 'preview.segment')),
        )
        .toList(),
  );

  final List<PreviewSegment> segments;

  Map<String, Object?> toJson() => <String, Object?>{
    'segments': segments
        .map((PreviewSegment segment) => segment.toJson())
        .toList(),
  };
}
