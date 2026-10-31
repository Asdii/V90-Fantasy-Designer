import 'dart:convert';

import '../models/calibration_profile.dart';
import '../models/validation.dart';
import 'json_storage.dart';
import 'key_value_store.dart';

class CalibrationRepository {
  CalibrationRepository(KeyValueStore store)
    : _store = store,
      _collection = JsonCollection<CalibrationProfile>(
        store: store,
        key: storageKey,
        fromJson: CalibrationProfile.fromJson,
        toJson: (CalibrationProfile profile) => profile.toJson(),
        idOf: (CalibrationProfile profile) => profile.id,
      );

  static const String storageKey = 'microfantasy.calibration.v1';
  static const String legacyBackupKey =
      'microfantasy.calibration.legacy-profiles';
  final KeyValueStore _store;
  final JsonCollection<CalibrationProfile> _collection;

  /// Atomically adopts the single calibration, preserving old multi-profile
  /// installations in a one-time local backup before migration.
  Future<void> replaceWith(CalibrationProfile profile) =>
      serializeStoreOperation(_store, storageKey, () async {
        final previous = await _store.getString(storageKey);
        if (previous != null) {
          final items = decodeEnvelope(previous)['items'] as List;
          if (items.length > 1 &&
              await _store.getString(legacyBackupKey) == null) {
            await _store.setString(legacyBackupKey, previous);
          }
        }
        await _store.setString(
          storageKey,
          jsonEncode({
            'schemaVersion': 1,
            'items': [profile.toJson()],
          }),
        );
      });

  Future<List<CalibrationProfile>> load() => _collection.load();
  Future<void> save(CalibrationProfile profile) => _collection.save(profile);

  /// Active profile selection belongs to AppSettings; callers should clear
  /// that selection when deleting the selected profile.
  Future<void> delete(String id) => _collection.delete(id);

  CalibrationProfile importJson(String source) =>
      CalibrationProfile.fromJson(jsonObject(jsonDecode(source), 'profile'));

  String exportJson(CalibrationProfile profile) =>
      const JsonEncoder.withIndent('  ').convert(profile.toJson());
}
