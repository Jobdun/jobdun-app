/// One persisted cache entry: a JSON-decodable [payload] plus the time it was
/// fetched (for stale-while-revalidate freshness checks).
class CacheRecord {
  const CacheRecord({required this.payload, required this.fetchedAt});

  /// The decoded JSON value — a `Map`/`List` of primitives. Callers re-hydrate
  /// their own entities from this.
  final Object payload;

  /// When the underlying data was fetched from the network.
  final DateTime fetchedAt;
}

/// A small key→record persistence seam for Phase 2 of
/// `docs/CACHING_ARCHITECTURE.md` (stale-while-revalidate + offline last-known).
///
/// Two guarantees that make a disk cache *safe* (doc §3.3, given Jobdun's
/// schema-drift history):
/// - **Schema versioning:** every entry is stamped with a `schemaVersion`;
///   [read] returns null when the stored version differs from the one asked
///   for, and purges the stale entry (purge-on-bump).
/// - **Fail-safe:** [read] never throws. An unparseable / corrupt entry reads
///   as null (and is purged), degrading to a cold cache instead of a crash.
abstract interface class CacheStore {
  /// The record for [key], or null if absent / version-mismatched / unreadable.
  Future<CacheRecord?> read(String key, {required int schemaVersion});

  /// Persist [payload] (a JSON-encodable value) under [key], stamped with
  /// [schemaVersion] and [at] (defaults to `DateTime.now()`).
  Future<void> write(
    String key,
    Object payload, {
    required int schemaVersion,
    DateTime? at,
  });

  /// Remove a single entry.
  Future<void> evict(String key);

  /// Remove every entry (e.g. on logout / account switch).
  Future<void> clear();
}
