import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cache_store.dart';
import 'in_memory_cache_store.dart';

/// App-wide persistent [CacheStore] (Phase 2, docs/CACHING_ARCHITECTURE.md).
///
/// Defaults to [InMemoryCacheStore] so the app — and every test — degrades
/// gracefully to "no cross-restart persistence" when nothing overrides it.
/// `main()` overrides it with a Hive-backed store for real disk caching;
/// tests override it via `ProviderScope` when they want to assert persistence.
final cacheStoreProvider = Provider<CacheStore>((ref) => InMemoryCacheStore());
