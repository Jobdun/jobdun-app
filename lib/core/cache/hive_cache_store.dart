import 'package:hive_ce/hive_ce.dart';

import 'string_backed_cache_store.dart';

/// Disk-backed [CacheStore] (Phase 2). Stores JSON-string records in a Hive box,
/// so cached reads survive app restarts and power offline last-known data.
///
/// Phase 2.5 will open this box with a `HiveAesCipher` for encryption at rest;
/// the store code is unchanged by that — only how the box is opened in `main()`.
class HiveCacheStore extends StringBackedCacheStore {
  HiveCacheStore(this._box, {super.maxEntries});

  final Box<String> _box;

  @override
  String? rawGet(String key) => _box.get(key);

  @override
  Future<void> rawPut(String key, String value) => _box.put(key, value);

  @override
  Future<void> rawDelete(String key) => _box.delete(key);

  @override
  Iterable<String> rawKeys() => _box.keys.cast<String>();

  @override
  Future<void> clear() => _box.clear();
}
