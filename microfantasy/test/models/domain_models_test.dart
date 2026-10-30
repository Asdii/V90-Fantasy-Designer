import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/models/app_settings.dart';
import 'package:microfantasy/models/fantasy_job.dart';

Map<String, Object?> validJobJson() => <String, Object?>{
  'jobId': 'job-1',
  'name': 'First cut',
  'units': 'mm',
  'steps': <Object?>[
    <String, Object?>{'index': 1, 'angleR': 90, 'x': -2.5, 'depth': 0.1},
  ],
};

void main() {
  group('standalone job schema', () {
    test('FantasyJob alias parses the specified jobId/mm schema', () {
      final FantasyJob job = FantasyJob.fromJson(validJobJson());
      expect(job.jobId, 'job-1');
      expect(job.id, 'job-1');
      expect(job.units, 'mm');
      expect(job.steps.single.x, -2.5);
      expect(job.toJson(), validJobJson());
      expect(job.toJson().containsKey('id'), isFalse);
      expect(job.preview, isNull);
    });

    test(
      'requires jobId and mm units; display units never reinterpret jobs',
      () {
        final Map<String, Object?> legacy = validJobJson()..remove('jobId');
        legacy['id'] = 'job-1';
        expect(() => FantasyJob.fromJson(legacy), throwsFormatException);
        expect(
          () => FantasyJob.fromJson(validJobJson()..remove('units')),
          throwsFormatException,
        );
        for (final Object? units in <Object?>['cm', 'MM', '', null, 1]) {
          expect(
            () => FantasyJob.fromJson(validJobJson()..['units'] = units),
            throwsFormatException,
          );
        }
      },
    );

    test('rejects missing fields and wrong JSON shapes', () {
      for (final String field in <String>['jobId', 'name', 'steps']) {
        expect(
          () => FantasyJob.fromJson(validJobJson()..remove(field)),
          throwsFormatException,
        );
      }
      for (final Object? steps in <Object?>[
        null,
        'steps',
        <String, Object?>{},
        <Object?>[],
        <Object?>[null],
      ]) {
        expect(
          () => FantasyJob.fromJson(validJobJson()..['steps'] = steps),
          throwsFormatException,
        );
      }
      expect(
        () => FantasyJob.fromJson(validJobJson()..['name'] = '  '),
        throwsFormatException,
      );
    });

    test('rejects malformed numeric fields without coercion', () {
      for (final String field in <String>['index', 'angleR', 'x', 'depth']) {
        for (final Object? value in <Object?>[
          null,
          '1',
          true,
          double.nan,
          double.infinity,
        ]) {
          final Map<String, Object?> step = <String, Object?>{
            'index': 1,
            'angleR': 90,
            'x': 2,
            'depth': 0.1,
          }..[field] = value;
          expect(
            () => FantasyStep.fromJson(step),
            throwsFormatException,
            reason: '$field: $value',
          );
        }
      }
      expect(
        () => FantasyStep.fromJson(<String, Object?>{
          'index': 1.5,
          'angleR': 0,
          'x': 0,
          'depth': 0,
        }),
        throwsFormatException,
      );
    });

    test('checks physical limits in constructors, independently of JSON', () {
      expect(
        () => FantasyStep(index: -1, angleR: 0, x: 0, depth: 0),
        throwsFormatException,
      );
      expect(
        () => FantasyStep(index: 1, angleR: -1, x: 0, depth: 0),
        throwsFormatException,
      );
      expect(
        () => FantasyStep(index: 1, angleR: 361, x: 0, depth: 0),
        throwsFormatException,
      );
      expect(
        () => FantasyStep(index: 1, angleR: 0, x: 0, depth: -0.1),
        throwsFormatException,
      );
      expect(FantasyStep(index: 0, angleR: 360, x: -2, depth: 0).angleR, 360);
    });

    test('preserves sequence and protects it from caller mutation', () {
      final List<CuttingStep> source = <CuttingStep>[
        CuttingStep(index: 8, angleR: 180, x: 2, depth: 0.2),
        CuttingStep(index: 2, angleR: 90, x: 1, depth: 0.1),
      ];
      final CuttingJob job = CuttingJob(
        jobId: 'ordered',
        name: 'Ordered',
        steps: source,
      );
      source.clear();
      expect(job.steps.map((CuttingStep step) => step.index), <int>[8, 2]);
      expect(() => job.steps.clear(), throwsUnsupportedError);
      expect(
        () => job.copyWith(
          steps: <CuttingStep>[job.steps.first, job.steps.first],
        ),
        throwsFormatException,
      );
    });

    test('demo survives JSON encoding with linked normalized preview', () {
      final FantasyJob demo = FantasyJob.demo();
      final FantasyJob restored = FantasyJob.fromJson(
        jsonDecode(jsonEncode(demo.toJson())) as Map<String, Object?>,
      );
      expect(restored.toJson(), demo.toJson());
      expect(restored.steps, hasLength(6));
      expect(restored.preview!.segments, hasLength(6));
      expect(
        restored.preview!.segments.first.stepIndex,
        restored.steps.first.index,
      );
      expect(
        restored.copyWith(clearPreview: true).toJson().containsKey('preview'),
        isFalse,
      );
    });

    test('rejects out-of-range preview coordinates and missing step links', () {
      expect(() => PreviewPoint(x: -0.01, y: 0.5), throwsFormatException);
      expect(() => PreviewPoint(x: 0.5, y: 1.01), throwsFormatException);
      expect(() => PreviewPoint(x: double.nan, y: 0), throwsFormatException);
      final JobPreview preview = JobPreview(
        segments: <PreviewSegment>[
          PreviewSegment(
            start: PreviewPoint(x: 0, y: 0),
            end: PreviewPoint(x: 1, y: 1),
            stepIndex: 999,
          ),
        ],
      );
      expect(
        () => FantasyJob.demo().copyWith(preview: preview),
        throwsFormatException,
      );
      expect(
        () => FantasyJob.fromJson(
          validJobJson()..['preview'] = <String, Object?>{'segments': 'bad'},
        ),
        throwsFormatException,
      );
    });
  });

  group('settings', () {
    test('fresh install uses the specified defaults', () {
      final AppSettings settings = AppSettings();
      expect(settings.toJson(), <String, Object?>{
        'simulation': true,
        'host': 'fantasy-machine.local',
        'port': 81,
        'timeoutSeconds': 5,
        'units': 'mm',
        'invertX': false,
        'tolerance': 0.05,
        'smoothing': 'off',
        'angleInterval': 30,
        'activeProfileId': null,
        'haptics': true,
        'autoAdvance': false,
      });
      expect(settings.timeout, const Duration(seconds: 5));
      expect(
        AppSettings.fromJson(<String, Object?>{}).toJson(),
        settings.toJson(),
      );
    });

    test(
      'copyWith and JSON preserve all settings and explicitly clear a profile',
      () {
        final AppSettings original = AppSettings();
        final AppSettings edited = original.copyWith(
          simulation: false,
          host: '192.168.1.20',
          port: 8081,
          timeoutSeconds: 8,
          units: LengthUnit.cm,
          invertX: true,
          tolerance: 0.02,
          smoothing: SmoothingLevel.medium,
          angleInterval: 45,
          activeProfileId: 'stone-a',
          haptics: false,
          autoAdvance: true,
        );
        final AppSettings restored = AppSettings.fromJson(
          jsonDecode(jsonEncode(edited.toJson())) as Map<String, Object?>,
        );
        expect(restored.toJson(), edited.toJson());
        expect(restored.copyWith().activeProfileId, 'stone-a');
        expect(
          restored.copyWith(clearActiveProfileId: true).activeProfileId,
          isNull,
        );
        expect(original.simulation, isTrue);
        expect(original.activeProfileId, isNull);
      },
    );

    test(
      'missing fields may default but present malformed values must fail',
      () {
        for (final MapEntry<String, Object?> invalid in <String, Object?>{
          'simulation': 'true',
          'host': null,
          'port': 1.5,
          'timeoutSeconds': 0,
          'units': 'inch',
          'invertX': 1,
          'tolerance': double.infinity,
          'smoothing': 'heavy',
          'angleInterval': 0,
          'activeProfileId': ' ',
          'haptics': null,
          'autoAdvance': 'false',
        }.entries) {
          expect(
            () => AppSettings.fromJson(<String, Object?>{
              invalid.key: invalid.value,
            }),
            throwsFormatException,
            reason: invalid.key,
          );
        }
      },
    );

    test('validates connection fields and numeric bounds', () {
      for (final String host in <String>[
        '',
        ' host',
        'http://host',
        'host:81',
        'host/path',
        'host?query',
        'user@host',
      ]) {
        expect(
          () => AppSettings(host: host),
          throwsFormatException,
          reason: host,
        );
      }
      expect(AppSettings(host: '[::1]').host, '[::1]');
      expect(() => AppSettings(port: 0), throwsFormatException);
      expect(() => AppSettings(port: 65536), throwsFormatException);
      expect(() => AppSettings(tolerance: -0.1), throwsFormatException);
      expect(() => AppSettings(angleInterval: 361), throwsFormatException);
      expect(AppSettings(tolerance: 0).tolerance, 0);
    });

    test('display conversion leaves domain millimetres independent', () {
      expect(LengthUnit.cm.fromMillimetres(25), 2.5);
      expect(LengthUnit.cm.toMillimetres(-2.5), -25);
      expect(LengthUnit.mm.toMillimetres(2.5), 2.5);
      expect(() => LengthUnit.cm.toMillimetres(1e308), throwsFormatException);
      expect(
        () => LengthUnit.mm.fromMillimetres(double.nan),
        throwsFormatException,
      );
    });
  });
}
