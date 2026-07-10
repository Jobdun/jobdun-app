import 'package:supabase_flutter/supabase_flutter.dart' hide StorageException;

import '../../../../core/errors/exceptions.dart';
import '../models/job_model.dart';

/// Kill switch for the shared server-side jobs-feed cache. Build with
/// `--dart-define=FEED_SERVER_CACHE=false` to bypass the Edge Function entirely
/// and read Postgres directly — a per-build rollback lever. (Removing the
/// Upstash secret server-side is the instant, no-rebuild lever; see
/// docs/JOBS_FEED_CACHE_PLAN.md.)
const bool kFeedServerCacheEnabled = bool.fromEnvironment(
  'FEED_SERVER_CACHE',
  defaultValue: true,
);

/// Reads the default, unfiltered feed first page through the `jobs-feed` Edge
/// Function (Upstash-backed shared cache). The app never touches Redis directly
/// — the function is the only seam. Every failure surfaces as [ServerException]
/// so the repository can fall back to a direct Postgres read.
abstract interface class JobFeedCacheDataSource {
  Future<List<JobModel>> getFirstPage({int? limit});

  /// Best-effort cache bust after a job write. Never throws.
  Future<void> invalidate();
}

class JobFeedCacheDataSourceImpl implements JobFeedCacheDataSource {
  const JobFeedCacheDataSourceImpl(this._client);
  final SupabaseClient _client;

  static const _fn = 'jobs-feed';

  @override
  Future<List<JobModel>> getFirstPage({int? limit}) async {
    try {
      final response = await _client.functions.invoke(
        _fn,
        body: {'action': 'read', 'limit': ?limit},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['jobs'] is List) {
        return (data['jobs'] as List)
            .map((e) => JobModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw const ServerException('jobs-feed returned an unexpected payload');
    } on ServerException {
      rethrow;
    } on FunctionException catch (e) {
      throw ServerException('jobs-feed failed: ${e.details ?? e.reasonPhrase}');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> invalidate() async {
    try {
      await _client.functions.invoke(_fn, body: {'action': 'invalidate'});
    } catch (_) {
      // Best-effort — the 45s TTL is the safety net. Never surface to caller.
    }
  }
}
