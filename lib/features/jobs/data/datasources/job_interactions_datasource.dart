import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/job_model.dart';

abstract interface class JobInteractionsDataSource {
  Future<void> saveJob(String userId, String jobId);
  Future<void> unsaveJob(String userId, String jobId);
  Future<void> hideJob(String userId, String jobId);
  Future<Set<String>> getSavedJobIds(String userId);
  Future<Set<String>> getHiddenJobIds(String userId);
  Future<List<JobModel>> getSavedJobs(String userId);
}

class JobInteractionsDataSourceImpl implements JobInteractionsDataSource {
  const JobInteractionsDataSourceImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<void> saveJob(String userId, String jobId) async {
    try {
      // RLS allows the row owner to insert; ON CONFLICT on the primary key
      // (user_id, job_id) is implicit — re-saving silently no-ops via the
      // upsert path.
      await _client.from('saved_jobs').upsert({
        'user_id': userId,
        'job_id': jobId,
      });
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> unsaveJob(String userId, String jobId) async {
    try {
      await _client
          .from('saved_jobs')
          .delete()
          .eq('user_id', userId)
          .eq('job_id', jobId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> hideJob(String userId, String jobId) async {
    try {
      await _client.from('hidden_jobs').upsert({
        'user_id': userId,
        'job_id': jobId,
      });
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Set<String>> getSavedJobIds(String userId) async {
    try {
      final rows = await _client
          .from('saved_jobs')
          .select('job_id')
          .eq('user_id', userId);
      return (rows as List)
          .map((r) => (r as Map<String, dynamic>)['job_id'] as String)
          .toSet();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Set<String>> getHiddenJobIds(String userId) async {
    try {
      final rows = await _client
          .from('hidden_jobs')
          .select('job_id')
          .eq('user_id', userId);
      return (rows as List)
          .map((r) => (r as Map<String, dynamic>)['job_id'] as String)
          .toSet();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<JobModel>> getSavedJobs(String userId) async {
    try {
      // Join saved_jobs → jobs. PostgREST's embedded-resource select syntax
      // gives us nested job rows ordered by saved_jobs.created_at via the
      // foreign-key relationship we created in the migration.
      final rows = await _client
          .from('saved_jobs')
          .select('created_at, jobs(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => (r as Map<String, dynamic>)['jobs'])
          .whereType<Map<String, dynamic>>()
          .map(JobModel.fromJson)
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
