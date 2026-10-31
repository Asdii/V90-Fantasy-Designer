import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:microfantasy/models/app_settings.dart';
import 'package:microfantasy/repositories/key_value_store.dart';
import 'package:microfantasy/repositories/settings_repository.dart';

void main() {
  group('appearance settings', () {
    test('fresh and unthemed legacy settings use Claro', () {
      expect(AppSettings().appearance, AppearanceTheme.light);
      expect(
        AppSettings.fromJson(<String, Object?>{}).appearance,
        AppearanceTheme.light,
      );
      final legacy = AppSettings(
        invertX: true,
        activeProfileId: 'legacy-calibration',
        units: LengthUnit.cm,
      ).toJson()..remove('appearance');
      final restored = AppSettings.fromJson(legacy);
      expect(restored.appearance, AppearanceTheme.light);
      expect(restored.invertX, isTrue);
      expect(restored.activeProfileId, 'legacy-calibration');
      expect(restored.units, LengthUnit.cm);
    });

    for (final appearance in AppearanceTheme.values) {
      test(
        '${appearance.name} survives JSON and repository recreation',
        () async {
          final settings = AppSettings(appearance: appearance);
          final encoded = jsonEncode(settings.toJson());
          final json = jsonDecode(encoded) as Map<String, Object?>;
          expect(json['appearance'], appearance.name);
          expect(AppSettings.fromJson(json).appearance, appearance);

          final store = MemoryStore();
          await SettingsRepository(store).save(settings);
          final restarted = SettingsRepository(MemoryStore(store.snapshot));
          expect((await restarted.load()).toJson(), settings.toJson());
        },
      );
    }

    test('editing appearance preserves all unrelated and legacy settings', () {
      final original = AppSettings(
        simulation: false,
        host: '192.168.1.42',
        port: 8081,
        timeoutSeconds: 10,
        units: LengthUnit.cm,
        invertX: true,
        tolerance: .02,
        smoothing: SmoothingLevel.medium,
        angleInterval: 45,
        activeProfileId: 'legacy-calibration',
        haptics: false,
        autoAdvance: true,
      );
      final changed = original.copyWith(appearance: AppearanceTheme.amethyst);
      expect(changed.toJson(), <String, Object?>{
        ...original.toJson(),
        'appearance': 'amethyst',
      });
      expect(original.appearance, AppearanceTheme.light);
      expect(changed.copyWith().appearance, AppearanceTheme.amethyst);
      expect(
        changed.copyWith(units: LengthUnit.mm).appearance,
        AppearanceTheme.amethyst,
      );
      expect(
        changed.copyWith(clearActiveProfileId: true).appearance,
        AppearanceTheme.amethyst,
      );
      expect(
        changed.copyWith(appearance: AppearanceTheme.atelier).appearance,
        AppearanceTheme.atelier,
      );
    });

    test('present malformed appearance values are rejected', () {
      for (final invalid in <Object?>[
        null,
        '',
        'dark-unknown',
        'Atelier',
        0,
        false,
        <String>['atelier'],
        <String, String>{'name': 'atelier'},
      ]) {
        expect(
          () => AppSettings.fromJson(<String, Object?>{'appearance': invalid}),
          throwsFormatException,
          reason: '$invalid',
        );
      }
    });

    test('legacy stored settings gain appearance on their next save', () async {
      final legacy = AppSettings(invertX: true).toJson()..remove('appearance');
      final store = MemoryStore(<String, String>{
        SettingsRepository.storageKey: jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'settings': legacy,
        }),
      });
      final repository = SettingsRepository(store);
      final restored = await repository.load();
      expect(restored.appearance, AppearanceTheme.light);
      expect(restored.invertX, isTrue);
      await repository.save(
        restored.copyWith(appearance: AppearanceTheme.porcelain),
      );
      final restarted = SettingsRepository(MemoryStore(store.snapshot));
      final saved = await restarted.load();
      expect(saved.appearance, AppearanceTheme.porcelain);
      expect(saved.invertX, isTrue);
    });
  });
}
