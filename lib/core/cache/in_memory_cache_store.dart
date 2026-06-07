import 'string_backed_cache_store.dart';

/// Process-lifetime [CacheStore] — the graceful default when no disk store is
/// wired. A cache that isn't configured degrades to "no persistence", never a
/// crash. `main()` overrides the provider with a disk-backed store for real
/// cross-restart persistence.
class InMemoryCacheStore extends StringBackedCacheStore {
  final _box = <String, String>{};

  @override
  String? rawGet(String key) => _box[key];

  @override
  Future<void> rawPut(String key, String value) async => _box[key] = value;

  @override
  Future<void> rawDelete(String key) async => _box.remove(key);

  @override
  Future<void> clear() async => _box.clear();
}
