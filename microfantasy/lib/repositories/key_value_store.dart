/// Minimal async persistence contract, independent of Flutter or plugins.
abstract interface class KeyValueStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

/// A separate instance represents a fresh install; reuse it to simulate restart.
class MemoryStore implements KeyValueStore {
  MemoryStore([Map<String, String>? initialValues])
    : _values = Map<String, String>.of(initialValues ?? <String, String>{});

  final Map<String, String> _values;

  Map<String, String> get snapshot => Map<String, String>.unmodifiable(_values);

  @override
  Future<String?> getString(String key) async => _values[key];

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}
