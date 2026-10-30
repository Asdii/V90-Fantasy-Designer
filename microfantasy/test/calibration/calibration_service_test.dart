import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/models/calibration_profile.dart';
import 'package:microfantasy/services/calibration/calibration_service.dart';

void main() {
  const CalibrationService service = CalibrationService();

  CalibrationProfile profile(
    List<CalibrationPoint> points, {
    double referenceX = 10,
  }) {
    return CalibrationProfile(
      id: 'stone-a',
      name: 'Stone A',
      referenceX: referenceX,
      points: points,
    );
  }

  group('circular linear calibration', () {
    test('interpolates measured X relative to the reference', () {
      final CalibrationProfile calibration = profile(<CalibrationPoint>[
        CalibrationPoint(angleR: 90, x: 14),
        CalibrationPoint(angleR: 0, x: 10),
        CalibrationPoint(angleR: 180, x: 8),
      ]);
      expect(service.offsetAt(calibration, 0), 0);
      expect(service.offsetAt(calibration, 90), 4);
      expect(service.offsetAt(calibration, 22.5), closeTo(1, 1e-12));
      expect(service.offsetAt(calibration, 45), closeTo(2, 1e-12));
      expect(service.offsetAt(calibration, 135), closeTo(1, 1e-12));
      expect(service.offsetAt(calibration, 180), -2);
    });

    test('uses angular distance for irregularly spaced measurements', () {
      final CalibrationProfile calibration = profile(<CalibrationPoint>[
        CalibrationPoint(angleR: 20, x: 11),
        CalibrationPoint(angleR: 100, x: 15),
        CalibrationPoint(angleR: 250, x: 9),
      ]);
      expect(service.offsetAt(calibration, 40), closeTo(2, 1e-12));
      expect(service.offsetAt(calibration, 175), closeTo(2, 1e-12));
    });

    test(
      'interpolates both sides of the seam without a zero-degree sample',
      () {
        final CalibrationProfile calibration = profile(<CalibrationPoint>[
          CalibrationPoint(angleR: 330, x: 14),
          CalibrationPoint(angleR: 30, x: 10),
          CalibrationPoint(angleR: 180, x: 11),
        ]);
        expect(service.offsetAt(calibration, 345), closeTo(3, 1e-12));
        expect(service.offsetAt(calibration, 0), closeTo(2, 1e-12));
        expect(service.offsetAt(calibration, 15), closeTo(1, 1e-12));
        expect(service.offsetAt(calibration, -15), closeTo(3, 1e-12));
        expect(service.offsetAt(calibration, 375), closeTo(1, 1e-12));
      },
    );

    test('interpolates last to first when zero is a measurement', () {
      final CalibrationProfile calibration = profile(<CalibrationPoint>[
        CalibrationPoint(angleR: 0, x: 10),
        CalibrationPoint(angleR: 270, x: 16),
      ]);
      expect(service.offsetAt(calibration, 315), closeTo(3, 1e-12));
      expect(service.offsetAt(calibration, 360), 0);
      expect(service.offsetAt(calibration, 720), 0);
      expect(service.offsetAt(calibration, -360), 0);
      expect(service.offsetAt(calibration, 359.999), closeTo(0, 0.001));
    });

    test('a single measurement is a constant offset at every angle', () {
      final CalibrationProfile calibration = profile(<CalibrationPoint>[
        CalibrationPoint(angleR: 42, x: 9.25),
      ]);
      for (final double angle in <double>[-720, -1, 0, 42, 300, 360, 1000]) {
        expect(service.offsetAt(calibration, angle), -0.75);
      }
    });

    test(
      'empty calibration cannot silently act as a completed zero offset',
      () {
        final CalibrationProfile calibration = profile(<CalibrationPoint>[]);
        expect(calibration.isCalibrated, isFalse);
        expect(() => service.offsetAt(calibration, 0), throwsStateError);
      },
    );

    test('corrects target with signed offset without inverting the target', () {
      final CalibrationProfile calibration = profile(<CalibrationPoint>[
        CalibrationPoint(angleR: 0, x: 9.5),
        CalibrationPoint(angleR: 180, x: 10.5),
      ]);
      expect(service.correctedX(profile: calibration, angleR: 0, x: 2), 1.5);
      expect(
        service.correctedX(profile: calibration, angleR: 180, x: -2),
        -1.5,
      );
      expect(service.correctedX(profile: calibration, angleR: 90, x: 2), 2);
    });

    test(
      'handles large finite opposite offsets without subtraction overflow',
      () {
        final CalibrationProfile calibration = profile(<CalibrationPoint>[
          CalibrationPoint(angleR: 0, x: -1e308),
          CalibrationPoint(angleR: 180, x: 1e308),
        ], referenceX: 0);
        expect(service.offsetAt(calibration, 90), 0);
        expect(service.offsetAt(calibration, 270), 0);
        expect(
          () => service.correctedX(profile: calibration, angleR: 180, x: 1e308),
          throwsFormatException,
        );
      },
    );
  });

  group('angle normalization and collection', () {
    test('normalizes negative angles, full turns and negative zero', () {
      expect(CalibrationService.normalizeAngle(-30), 330);
      expect(CalibrationService.normalizeAngle(390), 30);
      expect(CalibrationService.normalizeAngle(-750), 330);
      expect(CalibrationService.normalizeAngle(360), 0);
      expect(CalibrationService.normalizeAngle(-0.0).isNegative, isFalse);
    });

    test('rejects NaN and infinities at the calculation boundary', () {
      final CalibrationProfile calibration = profile(<CalibrationPoint>[
        CalibrationPoint(angleR: 0, x: 10),
      ]);
      for (final double value in <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          () => CalibrationService.normalizeAngle(value),
          throwsFormatException,
        );
        expect(
          () => service.offsetAt(calibration, value),
          throwsFormatException,
        );
        expect(
          () => service.correctedX(profile: calibration, angleR: 0, x: value),
          throwsFormatException,
        );
      }
    });

    test('wizard targets cover a turn without duplicating the seam', () {
      expect(service.sampleAngles(30), <double>[
        0,
        30,
        60,
        90,
        120,
        150,
        180,
        210,
        240,
        270,
        300,
        330,
      ]);
      expect(service.sampleAngles(100), <double>[0, 100, 200, 300]);
      expect(service.sampleAngles(360), <double>[0]);
      expect(() => service.sampleAngles(0), throwsFormatException);
      expect(() => service.sampleAngles(-30), throwsFormatException);
      expect(() => service.sampleAngles(361), throwsFormatException);
    });
  });

  group('profile data', () {
    test('normalizes and sorts a defensive copy of measurements', () {
      final List<CalibrationPoint> source = <CalibrationPoint>[
        CalibrationPoint(angleR: -30, x: 12),
        CalibrationPoint(angleR: 360, x: 10),
      ];
      final CalibrationProfile calibration = profile(source);
      expect(
        calibration.points.map((CalibrationPoint point) => point.angleR),
        <double>[0, 330],
      );
      expect(source.first.angleR, 330);
      source.clear();
      expect(calibration.points, hasLength(2));
      expect(() => calibration.points.clear(), throwsUnsupportedError);
    });

    test(
      'rejects duplicate circular angles and non-finite reference offsets',
      () {
        expect(
          () => profile(<CalibrationPoint>[
            CalibrationPoint(angleR: 0, x: 10),
            CalibrationPoint(angleR: 360, x: 11),
          ]),
          throwsFormatException,
        );
        expect(
          () => profile(<CalibrationPoint>[
            CalibrationPoint(angleR: 0, x: 1e308),
          ], referenceX: -1e308),
          throwsFormatException,
        );
        expect(
          () => profile(<CalibrationPoint>[], referenceX: double.nan),
          throwsFormatException,
        );
      },
    );

    test('replacing and removing a measurement use canonical angles', () {
      final CalibrationProfile original = profile(<CalibrationPoint>[
        CalibrationPoint(angleR: 0, x: 10),
        CalibrationPoint(angleR: 90, x: 12),
      ]);
      final CalibrationProfile updated = original.withPoint(
        CalibrationPoint(angleR: 360, x: 11),
      );
      expect(updated.points, hasLength(2));
      expect(updated.points.first.x, 11);
      expect(original.points.first.x, 10);
      expect(updated.withoutPoint(-270).points.single.angleR, 0);
    });

    test(
      'JSON round trip preserves reference and interpolated calibration',
      () {
        final CalibrationProfile original = profile(<CalibrationPoint>[
          CalibrationPoint(angleR: 330, x: 14),
          CalibrationPoint(angleR: 30, x: 10),
        ]);
        final Map<String, Object?> json =
            jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>;
        final CalibrationProfile restored = CalibrationProfile.fromJson(json);
        expect(restored.toJson(), original.toJson());
        expect(service.offsetAt(restored, 0), 2);
        expect(service.offsetAt(restored.copyWith(referenceX: 11), 0), 1);
      },
    );
  });
}
