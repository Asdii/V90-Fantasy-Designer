import 'dart:convert';

import '../models/validation.dart';
import 'key_value_store.dart';

final Expando<Map<String, Future<void>>> _pendingByStore =
    Expando<Map<String, Future<void>>>('microfantasy persistence queues');

/// Serializes reads/mutations for a key, including across repository instances
/// using the same store. A failed write does not poison the next operation.
/// This is an in-process queue, not a cross-isolate/database transaction.
Future<T> serializeStoreOperation<T>(
  KeyValueStore store,
  String key,
  Future<T> Function() operation,
) {
  final Map<String, Future<void>> pending = _pendingByStore[store] ??=
      <String, Future<void>>{};
  final Future<void> previous = pending[key] ?? Future<void>.value();
  final Future<T> result = previous.then<T>((void _) => operation());
  pending[key] = result.then<void>(
    (T _) {},
    onError: (Object error, StackTrace stackTrace) {},
  );
  return result;
}

Map<String, Object?> decodeEnvelope(String source) {
  final Map<String, Object?> envelope = jsonObject(
    jsonDecode(source),
    'stored data',
  );
  if (integer(envelope['schemaVersion'], 'schemaVersion') != 1) {
    throw const FormatException('Unsupported stored schemaVersion.');
  }
  return envelope;
}

/// Shared implementation for atomic per-key collections of immutable models.
class JsonCollection<T> {
  JsonCollection({
    required this.store,
    required this.key,
    required this.fromJson,
    required this.toJson,
    required this.idOf,
  });

  final KeyValueStore store;
  final String key;
  final T Function(Map<String, Object?>) fromJson;
  final Map<String, Object?> Function(T) toJson;
  final String Function(T) idOf;

  Future<List<T>> load() => serializeStoreOperation(store, key, _read);

  Future<List<T>> _read() async {
    final String? source = await store.getString(key);
    if (source == null) {
      return List<T>.unmodifiable(<T>[]);
    }
    final Map<String, Object?> envelope = decodeEnvelope(source);
    final List<T> items = jsonList(
      envelope['items'],
      'items',
    ).map((Object? value) => fromJson(jsonObject(value, 'item'))).toList();
    final Set<String> ids = <String>{};
    for (final T item in items) {
      if (!ids.add(idOf(item))) {
        throw FormatException('Duplicate stored id: ${idOf(item)}.');
      }
    }
    return List<T>.unmodifiable(items);
  }

  Future<void> save(T item) => serializeStoreOperation(store, key, () async {
    final List<T> items = List<T>.of(await _read());
    final int index = items.indexWhere(
      (T existing) => idOf(existing) == idOf(item),
    );
    if (index < 0) {
      items.add(item);
    } else {
      items[index] = item;
    }
    await _write(items);
  });

  Future<void> delete(String id) {
    nonEmptyString(id, 'id');
    return serializeStoreOperation(store, key, () async {
      final List<T> items = List<T>.of(await _read());
      final int previousLength = items.length;
      items.removeWhere((T item) => idOf(item) == id);
      if (items.length != previousLength) {
        await _write(items);
      }
    });
  }

  Future<void> _write(List<T> items) => store.setString(
    key,
    jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'items': items.map(toJson).toList(),
    }),
  );
}
