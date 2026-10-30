import 'job_preview.dart';
import 'cut_helper_data.dart';
import 'validation.dart';

export 'job_preview.dart';

/// One ordered operation. X and depth are always in millimetres.
class CuttingStep {
  factory CuttingStep({
    required int index,
    required double angleR,
    required double x,
    required double depth,
  }) {
    integer(index, 'step.index', min: 0);
    boundedNumber(angleR, 'step.angleR', 0, 360);
    finiteNumber(x, 'step.x');
    nonNegativeNumber(depth, 'step.depth');
    return CuttingStep._(index, angleR, x, depth);
  }

  const CuttingStep._(this.index, this.angleR, this.x, this.depth);

  factory CuttingStep.fromJson(Map<String, Object?> json) => CuttingStep(
    index: integer(json['index'], 'step.index', min: 0),
    angleR: finiteNumber(json['angleR'], 'step.angleR'),
    x: finiteNumber(json['x'], 'step.x'),
    depth: finiteNumber(json['depth'], 'step.depth'),
  );

  final int index;
  final double angleR;
  final double x;
  final double depth;

  CuttingStep copyWith({
    int? index,
    double? angleR,
    double? x,
    double? depth,
  }) => CuttingStep(
    index: index ?? this.index,
    angleR: angleR ?? this.angleR,
    x: x ?? this.x,
    depth: depth ?? this.depth,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'index': index,
    'angleR': angleR,
    'x': x,
    'depth': depth,
  };
}

/// Standalone MicroFantasy job schema; no V90 model or geometry dependency.
///
/// Step order is preserved exactly. Indices must be unique and non-negative,
/// but may be zero/one-based or non-contiguous.
class CuttingJob {
  factory CuttingJob({
    required String jobId,
    required String name,
    required List<CuttingStep> steps,
    String units = 'mm',
    JobPreview? preview,
    CutHelperData? cutHelper,
  }) {
    nonEmptyString(jobId, 'job.jobId');
    nonEmptyString(name, 'job.name');
    if (units != 'mm') {
      throw const FormatException('job.units must be "mm".');
    }
    if (steps.isEmpty) {
      throw const FormatException('job.steps must contain at least one step.');
    }
    final Set<int> indices = <int>{};
    for (final CuttingStep step in steps) {
      if (!indices.add(step.index)) {
        throw FormatException('Duplicate step index: ${step.index}.');
      }
    }
    for (final PreviewSegment segment
        in preview?.segments ?? <PreviewSegment>[]) {
      if (segment.stepIndex != null && !indices.contains(segment.stepIndex)) {
        throw FormatException(
          'Preview references missing step ${segment.stepIndex}.',
        );
      }
    }
    if (cutHelper != null) {
      if (cutHelper.steps.length != steps.length) {
        throw const FormatException(
          'Cut Helper step count differs from the job.',
        );
      }
      for (var i = 0; i < steps.length; i++) {
        final h = cutHelper.steps[i];
        final s = steps[i];
        final angleError = ((h.segment.angle - s.angleR + 540) % 360 - 180)
            .abs();
        if (h.index != s.index ||
            angleError > 1e-7 ||
            !closeHelperNumber(
              s.x,
              cutHelper.machineCenterXmm + h.signedDistanceMm,
            )) {
          throw const FormatException(
            'Cut Helper and target coordinates do not agree.',
          );
        }
      }
    }
    return CuttingJob._(
      jobId,
      name,
      List<CuttingStep>.unmodifiable(steps),
      preview,
      cutHelper,
    );
  }

  const CuttingJob._(
    this.jobId,
    this.name,
    this.steps,
    this.preview,
    this.cutHelper,
  );

  factory CuttingJob.fromJson(Map<String, Object?> json) => CuttingJob(
    jobId: nonEmptyString(json['jobId'], 'job.jobId'),
    name: nonEmptyString(json['name'], 'job.name'),
    units: nonEmptyString(json['units'], 'job.units'),
    steps: jsonList(json['steps'], 'job.steps')
        .map(
          (Object? value) =>
              CuttingStep.fromJson(jsonObject(value, 'job.step')),
        )
        .toList(),
    preview: json['preview'] == null
        ? null
        : JobPreview.fromJson(jsonObject(json['preview'], 'job.preview')),
    cutHelper: json['cutHelper'] == null
        ? null
        : CutHelperData.fromJson(jsonObject(json['cutHelper'], 'cutHelper')),
  );

  factory CuttingJob.demo() {
    final List<PreviewPoint> corners = <PreviewPoint>[
      PreviewPoint(x: 0.5, y: 0.08),
      PreviewPoint(x: 0.86, y: 0.29),
      PreviewPoint(x: 0.86, y: 0.71),
      PreviewPoint(x: 0.5, y: 0.92),
      PreviewPoint(x: 0.14, y: 0.71),
      PreviewPoint(x: 0.14, y: 0.29),
    ];
    return CuttingJob(
      jobId: 'demo-hexagon',
      name: 'Hexágono de práctica',
      steps: List<CuttingStep>.generate(
        6,
        (int i) =>
            CuttingStep(index: i + 1, angleR: i * 60.0, x: 2, depth: 0.1),
      ),
      preview: JobPreview(
        segments: List<PreviewSegment>.generate(
          6,
          (int i) => PreviewSegment(
            start: corners[i],
            end: corners[(i + 1) % 6],
            stepIndex: i + 1,
          ),
        ),
      ),
    );
  }

  final String jobId;
  final String name;
  final List<CuttingStep> steps;
  final JobPreview? preview;
  final CutHelperData? cutHelper;

  String get id => jobId;
  String get units => 'mm';

  CuttingJob copyWith({
    String? name,
    List<CuttingStep>? steps,
    JobPreview? preview,
    bool clearPreview = false,
    CutHelperData? cutHelper,
  }) => CuttingJob(
    jobId: jobId,
    name: name ?? this.name,
    steps: steps ?? this.steps,
    preview: clearPreview ? null : preview ?? this.preview,
    cutHelper: cutHelper ?? this.cutHelper,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'jobId': jobId,
    'name': name,
    'units': units,
    'steps': steps.map((CuttingStep step) => step.toJson()).toList(),
    if (preview != null) 'preview': preview!.toJson(),
    if (cutHelper != null) 'cutHelper': cutHelper!.toJson(),
  };
}

typedef FantasyJob = CuttingJob;
typedef FantasyStep = CuttingStep;
