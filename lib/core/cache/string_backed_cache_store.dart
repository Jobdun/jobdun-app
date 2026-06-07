import 'dart:convert';

import 'cache_store.dart';

/// Shared serialization for [CacheStore] backends. Every entry is a JSON string
/// `{"v":schemaVersion,"t":millis,"p":payload}`. Storing a *string* (rather than
/// a raw Map) sidesteps backend type-coercion (Hive hands back
/// `Map<dynamic, dynamic>`) and gives identical version + fail-safe semantics
/// across every backend. Subclasses only supply raw key→string access.
abstract class StringBackedCacheStore implements CacheStore {
  StringBackedCacheStore({this.maxEntries = 200});

  /// Hard cap on stored entries. On write, the oldest entries beyond this are
  /// evicted (FIFO) so the cache can't grow without bound (docs/CACHING §3.3).
  final int maxEntries;

  String? rawGet(String key);
  Future<void> rawPut(String key, String value);
  Future<void> rawDelete(String key);

  /// Keys in insertion order (oldest first) — drives eviction.
  Iterable<String> rawKeys();

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
  }) async {
    final stamped = (at ?? DateTime.now()).millisecondsSinceEpoch;
    await rawPut(
      key,
      jsonEncode({'v': schemaVersion, 't': stamped, 'p': payload}),
    );
    await _enforceBound(justWrote: key);
  }

  /// Evict oldest entries (FIFO) until at most [maxEntries] remain. Never evicts
  /// the entry just written.
  Future<void> _enforceBound({required String justWrote}) async {
    final keys = rawKeys().toList(growable: false);
    var over = keys.length - maxEntries;
    for (var i = 0; over > 0 && i < keys.length; i++) {
      if (keys[i] == justWrote) continue;
      await rawDelete(keys[i]);
      over--;
    }
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
