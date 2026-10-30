import 'dart:convert';

import '../models/app_settings.dart';
import '../models/validation.dart';
import 'json_storage.dart';
import 'key_value_store.dart';

class SettingsRepository {
  SettingsRepository(this.store);

  static const String storageKey = 'microfantasy.settings.v1';
  final KeyValueStore store;

  /// Only missing settings use defaults. Corruption is surfaced to the caller.
  Future<AppSettings> load() => serializeStoreOperation(
    store,
    storageKey,
    () async {
      final String? source = await store.getString(storageKey);
      if (source == null) {
        return AppSettings();
      }
      final Map<String, Object?> envelope = decodeEnvelope(source);
      return AppSettings.fromJson(jsonObject(envelope['settings'], 'settings'));
    },
  );

  Future<void> save(AppSettings settings) =>
      serializeStoreOperation(store, storageKey, () {
        return store.setString(
          storageKey,
          jsonEncode(<String, Object?>{
            'schemaVersion': 1,
            'settings': settings.toJson(),
          }),
        );
      });

  Future<void> reset() => serializeStoreOperation(
    store,
    storageKey,
    () => store.remove(storageKey),
  );
}
