import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Default in-memory cache window for hot read providers (home tiles, builder
/// listings, counts). Three minutes balances "instant on return" against
/// staleness — see `docs/CACHING_ARCHITECTURE.md` §3.1.
const kDefaultCacheTtl = Duration(minutes: 3);

/// Jobdun's single in-memory TTL caching primitive (Phase 1 of
/// `docs/CACHING_ARCHITECTURE.md`).
///
/// Call once at the top of an **`autoDispose`** provider body so its last
/// result is kept alive for [ttl] after it is built, instead of being thrown
/// away the moment the screen is unlistened. Navigating away and back within
/// [ttl] reuses the cached value; after [ttl] the provider is released and a
/// fresh fetch runs on the next read.
///
/// ```dart
/// final fooProvider = FutureProvider.autoDispose<Foo>((ref) async {
///   cacheFor(ref, kDefaultCacheTtl);
///   return ref.read(repoProvider).fetch();
/// });
/// ```
///
/// Safe to call on a non-`autoDispose` provider — `keepAlive()` is a no-op
/// there — but it only does useful work on `autoDispose` ones.
void cacheFor(Ref ref, Duration ttl) {
  final link = ref.keepAlive();
  final timer = Timer(ttl, link.close);
  ref.onDispose(timer.cancel);
}
