import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/job_filter.dart';
import '../models/job_model.dart';

abstract interface class JobRemoteDataSource {
  Future<List<JobModel>> getJobs({JobFilter? filter, int? limit, int? offset});
  Future<List<JobModel>> getBuilderJobs(String builderId);
  Future<JobModel> getJobById(String id);
  Future<JobModel> createJob(JobModel job);
  Future<JobModel> updateJob(JobModel job);
  Future<void> softDeleteJob(String id);
  Future<void> updateJobStatus(String id, JobStatus status);
  Stream<List<JobModel>> watchBuilderJobs(String builderId);
}

class JobRemoteDataSourceImpl implements JobRemoteDataSource {
  const JobRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<List<JobModel>> getJobs({
    JobFilter? filter,
    int? limit,
    int? offset,
  }) async {
    try {
      var query = _client
          .from('jobs')
          .select(
            'id, builder_id, title, description, suburb, state, postcode, trade_type_required, budget_min, budget_max, budget_type, urgency, requires_verified, requires_white_card, application_count, view_count, status, published_at, created_at, updated_at',
          )
          .isFilter('deleted_at', null);

      if (filter != null && !filter.isEmpty) {
        if (filter.status != null) {
          query = query.eq('status', filter.status!.dbValue) as dynamic;
        }
        if (filter.tradeType != null) {
          query = query.eq('trade_type_required', filter.tradeType!) as dynamic;
        }
        if (filter.builderId != null) {
          // "Your listings" — scope the feed to one builder's own jobs. RLS
          // jobs_select_own then exposes all their statuses (incl. draft).
          query = query.eq('builder_id', filter.builderId!) as dynamic;
        }
        if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
          query =
              query.textSearch(
                    'search_vector',
                    filter.searchQuery!,
                    type: TextSearchType.websearch,
                  )
                  as dynamic;
        }
      }

      // Ordered ascending=false → newest first. PostgREST `.range(from, to)`
      // is inclusive on both ends, so a 20-item page is range(offset, offset+19).
      var ordered = (query as dynamic).order('published_at', ascending: false);
      if (limit != null) {
        final from = offset ?? 0;
        ordered = ordered.range(from, from + limit - 1);
      }
      final data = await ordered as List<dynamic>;
      return data
          .map((e) => JobModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  // One-shot fetch of a builder's own jobs (all statuses, non-deleted). Uses
  // `.select()` (full row) so JobModel.fromJson always has every column —
  // distinct from getJobs, whose trimmed feed projection must list each field.
  @override
  Future<List<JobModel>> getBuilderJobs(String builderId) async {
    try {
      final data =
          await _client
                  .from('jobs')
                  .select()
                  .eq('builder_id', builderId)
                  .isFilter('deleted_at', null)
                  .order('created_at', ascending: false)
              as List<dynamic>;
      return data
          .map((e) => JobModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<JobModel> getJobById(String id) async {
    try {
      final data = await _client
          .from('jobs')
          .select()
          .eq('id', id)
          .isFilter('deleted_at', null)
          .single();
      return JobModel.fromJson(data);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<JobModel> createJob(JobModel job) async {
    try {
      final json = job.toJson();
      // Created straight as 'open' → it's published now. The Draft→Open
      // transition that normally stamps published_at (see updateJobStatus) is
      // skipped on create, so set it here. Without it the feed's
      // `ORDER BY published_at DESC` sorts every fresh listing as NULL.
      if (job.status == JobStatus.open && json['published_at'] == null) {
        json['published_at'] = DateTime.now().toUtc().toIso8601String();
      }
      final data = await _client.from('jobs').insert(json).select().single();
      return JobModel.fromJson(data);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<JobModel> updateJob(JobModel job) async {
    try {
      final data = await _client
          .from('jobs')
          .update(job.toJson())
          .eq('id', job.id)
          .select()
          .single();
      return JobModel.fromJson(data);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  // Soft delete — never hard delete jobs (dispute history).
  @override
  Future<void> softDeleteJob(String id) async {
    try {
      await _client
          .from('jobs')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updateJobStatus(String id, JobStatus status) async {
    try {
      final update = <String, dynamic>{'status': status.dbValue};
      if (status == JobStatus.open)
        update['published_at'] = DateTime.now().toIso8601String();
      await _client.from('jobs').update(update).eq('id', id);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Stream<List<JobModel>> watchBuilderJobs(String builderId) {
    return _client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('builder_id', builderId)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .where((r) => r['deleted_at'] == null)
              .map(JobModel.fromJson)
              .toList(),
        );
  }
}
