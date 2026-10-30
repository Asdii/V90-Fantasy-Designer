import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/models/app_settings.dart';
import 'package:microfantasy/models/calibration_profile.dart';
import 'package:microfantasy/models/fantasy_job.dart';
import 'package:microfantasy/repositories/calibration_repository.dart';
import 'package:microfantasy/repositories/job_repository.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/repositories/settings_repository.dart';
import 'package:microfantasy/repositories/shared_preferences_store.dart';
import 'package:microfantasy/services/calibration/calibration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

CuttingJob job(String id) => CuttingJob(
  jobId: id,
  name: 'Job $id',
  steps: <CuttingStep>[CuttingStep(index: 1, angleR: 30, x: 2, depth: 0.1)],
);

CalibrationProfile profile(String id) => CalibrationProfile(
  id: id,
  name: 'Calibration $id',
  referenceX: 10,
  points: <CalibrationPoint>[
    CalibrationPoint(angleR: 330, x: 14),
    CalibrationPoint(angleR: 30, x: 10),
  ],
);

class FailingStore extends MemoryStore {
  bool failNextWrite = true;

  @override
  Future<void> setString(String key, String value) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('Disk write failed.');
    }
    await super.setString(key, value);
  }
}

class RecordingPreferences implements SharedPreferencesAsync {
  final Map<String, String> values = <String, String>{};
  final List<String> calls = <String>[];

  @override
  Future<String?> getString(String key) async {
    calls.add('get:$key');
    return values[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    calls.add('set:$key');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    calls.add('remove:$key');
    values.remove(key);
  }

  @override
  Never noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

void main() {
  group('settings persistence', () {
    test('missing settings use defaults without writing to storage', () async {
      final MemoryStore store = MemoryStore();
      final AppSettings settings = await SettingsRepository(store).load();
      expect(settings.toJson(), AppSettings().toJson());
      expect(store.snapshot, isEmpty);
    });

    test(
      'all settings survive repository/store recreation from saved JSON',
      () async {
        final MemoryStore store = MemoryStore();
        final AppSettings settings = AppSettings(
          simulation: false,
          host: '192.168.1.80',
          port: 8081,
          timeoutSeconds: 8,
          units: LengthUnit.cm,
          invertX: true,
          tolerance: 0.02,
          smoothing: SmoothingLevel.light,
          angleInterval: 45,
          activeProfileId: 'stone-a',
          haptics: false,
          autoAdvance: true,
        );
        await SettingsRepository(store).save(settings);
        final SettingsRepository restarted = SettingsRepository(
          MemoryStore(store.snapshot),
        );
        expect((await restarted.load()).toJson(), settings.toJson());
        await restarted.save(settings.copyWith(clearActiveProfileId: true));
        expect((await restarted.load()).activeProfileId, isNull);
      },
    );

    test('read queued after a save observes the completed write', () async {
      final SettingsRepository repository = SettingsRepository(MemoryStore());
      final Future<void> write = repository.save(AppSettings(port: 8082));
      final Future<AppSettings> read = repository.load();
      await write;
      expect((await read).port, 8082);
    });

    test(
      'reset removes only settings, leaving jobs and unrelated values',
      () async {
        final MemoryStore store = MemoryStore(<String, String>{
          'other-app': 'keep',
        });
        final SettingsRepository settings = SettingsRepository(store);
        await settings.save(AppSettings(simulation: false));
        await JobRepository(store).save(job('one'));
        await settings.reset();
        expect((await settings.load()).simulation, isTrue);
        expect((await JobRepository(store).load()).single.jobId, 'one');
        expect(await store.getString('other-app'), 'keep');
      },
    );

    test(
      'corrupt persisted settings surface an error and preserve source',
      () async {
        final String corrupt = jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'settings': <String, Object?>{'simulation': 'false'},
        });
        final MemoryStore store = MemoryStore(<String, String>{
          SettingsRepository.storageKey: corrupt,
        });
        await expectLater(
          SettingsRepository(store).load(),
          throwsFormatException,
        );
        expect(await store.getString(SettingsRepository.storageKey), corrupt);
      },
    );
  });

  group('job persistence', () {
    test(
      'import is side-effect free and export is the standalone mm schema',
      () async {
        final MemoryStore store = MemoryStore();
        final JobRepository repository = JobRepository(store);
        final CuttingJob imported = repository.importJson(
          repository.exportJson(FantasyJob.demo()),
        );
        expect(imported.toJson(), FantasyJob.demo().toJson());
        expect(await repository.load(), isEmpty);
        expect(store.snapshot, isEmpty);
        final Map<String, Object?> exported =
            jsonDecode(repository.exportJson(imported)) as Map<String, Object?>;
        expect(exported['jobId'], 'demo-hexagon');
        expect(exported['units'], 'mm');
        expect(exported.containsKey('id'), isFalse);
        expect(() => repository.importJson('[]'), throwsFormatException);
        expect(
          () => repository.importJson('{malformed'),
          throwsFormatException,
        );
      },
    );

    test(
      'upsert preserves order, reloads JSON, and deletes only requested id',
      () async {
        final MemoryStore store = MemoryStore();
        final JobRepository repository = JobRepository(store);
        await repository.save(job('a'));
        await repository.save(job('b'));
        await repository.save(job('a').copyWith(name: 'Updated A'));
        final JobRepository restarted = JobRepository(
          MemoryStore(store.snapshot),
        );
        final List<CuttingJob> loaded = await restarted.load();
        expect(loaded.map((CuttingJob item) => item.jobId), <String>['a', 'b']);
        expect(loaded.first.name, 'Updated A');
        expect(() => loaded.clear(), throwsUnsupportedError);
        await restarted.delete('a');
        await restarted.delete('missing');
        expect((await restarted.load()).single.jobId, 'b');
      },
    );

    test(
      'overlapping saves through different repositories do not lose jobs',
      () async {
        final MemoryStore store = MemoryStore();
        final JobRepository first = JobRepository(store);
        final JobRepository second = JobRepository(store);
        await Future.wait<void>(<Future<void>>[
          first.save(job('a')),
          second.save(job('b')),
          first.save(job('c')),
          second.save(job('a').copyWith(name: 'Newest A')),
        ]);
        final List<CuttingJob> jobs = await first.load();
        expect(jobs.map((CuttingJob item) => item.jobId), <String>[
          'a',
          'b',
          'c',
        ]);
        expect(jobs.first.name, 'Newest A');
      },
    );

    test(
      'a failed write propagates and later operations can still succeed',
      () async {
        final FailingStore store = FailingStore();
        final JobRepository repository = JobRepository(store);
        await expectLater(repository.save(job('lost')), throwsStateError);
        expect(await repository.load(), isEmpty);
        await repository.save(job('saved'));
        expect((await repository.load()).single.jobId, 'saved');
      },
    );

    test('malformed JSON is not erased by a subsequent save', () async {
      final MemoryStore store = MemoryStore(<String, String>{
        JobRepository.storageKey: '{broken',
      });
      final JobRepository repository = JobRepository(store);
      await expectLater(repository.load(), throwsFormatException);
      await expectLater(repository.save(job('new')), throwsFormatException);
      expect(await store.getString(JobRepository.storageKey), '{broken');
    });

    test('rejects unknown storage versions and duplicate stored IDs', () async {
      for (final Map<String, Object?> invalid in <Map<String, Object?>>[
        <String, Object?>{'schemaVersion': 2, 'items': <Object?>[]},
        <String, Object?>{
          'schemaVersion': 1,
          'items': <Object?>[job('a').toJson(), job('a').toJson()],
        },
        <String, Object?>{
          'schemaVersion': 1,
          'items': <Object?>[null],
        },
      ]) {
        final MemoryStore store = MemoryStore(<String, String>{
          JobRepository.storageKey: jsonEncode(invalid),
        });
        await expectLater(JobRepository(store).load(), throwsFormatException);
      }
    });
  });

  group('calibration persistence', () {
    test(
      'restores profiles, selected ID and circular correction after restart',
      () async {
        final MemoryStore store = MemoryStore();
        final CalibrationRepository repository = CalibrationRepository(store);
        await repository.save(profile('stone-a'));
        await repository.save(profile('stone-b').copyWith(referenceX: 11));
        await SettingsRepository(
          store,
        ).save(AppSettings(activeProfileId: 'stone-b'));

        final MemoryStore restartedStore = MemoryStore(store.snapshot);
        final List<CalibrationProfile> restored = await CalibrationRepository(
          restartedStore,
        ).load();
        final AppSettings settings = await SettingsRepository(
          restartedStore,
        ).load();
        final CalibrationProfile active = restored.singleWhere(
          (CalibrationProfile item) => item.id == settings.activeProfileId,
        );
        expect(restored, hasLength(2));
        expect(active.referenceX, 11);
        expect(
          active.points.map((CalibrationPoint point) => point.angleR),
          <double>[30, 330],
        );
        expect(const CalibrationService().offsetAt(active, 0), 1);
        expect(() => active.points.clear(), throwsUnsupportedError);
      },
    );

    test('upserts measurements and preserves unfinished drafts', () async {
      final MemoryStore store = MemoryStore();
      final CalibrationRepository repository = CalibrationRepository(store);
      await repository.save(profile('a'));
      await repository.save(
        profile('a').withPoint(CalibrationPoint(angleR: 360, x: 13)),
      );
      await repository.save(
        CalibrationProfile(
          id: 'draft',
          name: 'Draft',
          referenceX: 0,
          points: <CalibrationPoint>[],
        ),
      );
      final List<CalibrationProfile> restored = await CalibrationRepository(
        MemoryStore(store.snapshot),
      ).load();
      expect(restored, hasLength(2));
      expect(restored.first.points, hasLength(3));
      expect(const CalibrationService().offsetAt(restored.first, 0), 3);
      expect(restored.last.isCalibrated, isFalse);
    });

    test(
      'concurrent saves and deletion preserve unrelated profiles and jobs',
      () async {
        final MemoryStore store = MemoryStore();
        final CalibrationRepository first = CalibrationRepository(store);
        final CalibrationRepository second = CalibrationRepository(store);
        await Future.wait<void>(<Future<void>>[
          first.save(profile('a')),
          second.save(profile('b')),
          JobRepository(store).save(job('job')),
        ]);
        await first.delete('a');
        expect((await second.load()).single.id, 'b');
        expect((await JobRepository(store).load()).single.jobId, 'job');
      },
    );

    test(
      'profile export/import preserves calibration without saving it',
      () async {
        final CalibrationRepository repository = CalibrationRepository(
          MemoryStore(),
        );
        final CalibrationProfile original = profile('a');
        final CalibrationProfile imported = repository.importJson(
          repository.exportJson(original),
        );
        expect(imported.toJson(), original.toJson());
        expect(await repository.load(), isEmpty);
        expect(
          () => repository.importJson('{"id":"bad"}'),
          throwsFormatException,
        );
      },
    );

    test(
      'corrupt measurements fail loading without replacing stored data',
      () async {
        final Map<String, Object?> invalid = profile('a').toJson()
          ..['points'] = <Object?>[
            <String, Object?>{'angleR': 0, 'x': 10},
            <String, Object?>{'angleR': 360, 'x': 11},
          ];
        final String raw = jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'items': <Object?>[invalid],
        });
        final MemoryStore store = MemoryStore(<String, String>{
          CalibrationRepository.storageKey: raw,
        });
        await expectLater(
          CalibrationRepository(store).load(),
          throwsFormatException,
        );
        expect(await store.getString(CalibrationRepository.storageKey), raw);
      },
    );
  });

  group('store implementations', () {
    test(
      'MemoryStore isolates seed input and exposes an immutable snapshot',
      () async {
        final Map<String, String> seed = <String, String>{'a': 'initial'};
        final MemoryStore store = MemoryStore(seed);
        seed['a'] = 'mutated';
        expect(await store.getString('a'), 'initial');
        expect(() => store.snapshot['a'] = 'mutated', throwsUnsupportedError);
        await store.remove('a');
        expect(await store.getString('a'), isNull);
      },
    );

    test(
      'SharedPreferencesStore delegates async string operations without caching',
      () async {
        final RecordingPreferences preferences = RecordingPreferences();
        final SharedPreferencesStore store = SharedPreferencesStore(
          preferences: preferences,
        );
        await store.setString('a', 'one');
        expect(await store.getString('a'), 'one');
        preferences.values['a'] = 'external update';
        expect(await store.getString('a'), 'external update');
        preferences.values['unrelated'] = 'keep';
        await store.remove('a');
        expect(await store.getString('a'), isNull);
        expect(preferences.values['unrelated'], 'keep');
        expect(preferences.calls, <String>[
          'set:a',
          'get:a',
          'get:a',
          'remove:a',
          'get:a',
        ]);
      },
    );
  });
}
