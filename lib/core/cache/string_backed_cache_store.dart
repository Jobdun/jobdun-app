import 'dart:convert';

import 'cache_store.dart';

/// Shared serialization for [CacheStore] backends. Every entry is a JSON string
/// `{"v":schemaVersion,"t":millis,"p":payload}`. Storing a *string* (rather than
/// a raw Map) sidesteps backend type-coercion (Hive hands back
/// `Map<dynamic, dynamic>`) and gives identical version + fail-safe semantics
/// across every backend. Subclasses only supply raw key→string access.
abstract class StringBackedCacheStore implements CacheStore {
  String? rawGet(String key);
  Future<void> rawPut(String key, String value);
  Future<void> rawDelete(String key);

  @override
  Future<CacheRecord?> read(String key, {required int schemaVersion}) async {
    final raw = rawGet(key);
    if (raw == null) return null;
    final record = _decode(raw, schemaVersion);
    if (record == null) {
      await rawDelete(key); // purge stale-version / corrupt entry
    }
    return record;
  }

  @override
  Future<void> write(
    String key,
    Object payload, {
    required int schemaVersion,
    DateTime? at,
  }) {
    final stamped = (at ?? DateTime.now()).millisecondsSinceEpoch;
    return rawPut(
      key,
      jsonEncode({'v': schemaVersion, 't': stamped, 'p': payload}),
    );
  }

  @override
  Future<void> evict(String key) => rawDelete(key);

  CacheRecord? _decode(String raw, int expectedVersion) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['v'] != expectedVersion) return null;
      return CacheRecord(
        payload: map['p'] as Object,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(map['t'] as int),
      );
    } catch (_) {
      return null; // fail-safe: corrupt entry → cold cache, never a crash
    }
  }
}
