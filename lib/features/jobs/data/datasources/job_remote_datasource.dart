import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/job_filter.dart';
import '../models/job_model.dart';

abstract interface class JobRemoteDataSource {
  Future<List<JobModel>> getJobs({JobFilter? filter});
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

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Future<List<JobModel>> getJobs({JobFilter? filter}) async {
    try {
      var query = _client
          .from('jobs')
          .select(
            'id, builder_id, title, description, suburb, state, postcode, latitude, longitude, trade_type_required, budget_min, budget_max, budget_type, start_date, urgency, requires_verified, requires_white_card, application_count, view_count, status, published_at, created_at, updated_at',
          )
          .isFilter('deleted_at', null);

      if (filter != null && !filter.isEmpty) {
        if (filter.status != null) {
          query = query.eq('status', filter.status!.dbValue) as dynamic;
        }
        if (filter.tradeType != null) {
          query = query.eq('trade_type_required', filter.tradeType!) as dynamic;
        }
        if (filter.tradeTypes != null && filter.tradeTypes!.isNotEmpty) {
          query =
              query.inFilter('trade_type_required', filter.tradeTypes!)
                  as dynamic;
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
        // Budget overlap: job's ceiling >= requested floor and job's floor
        // <= requested ceiling.
        if (filter.budgetMin != null) {
          query = query.gte('budget_max', filter.budgetMin!) as dynamic;
        }
        if (filter.budgetMax != null) {
          query = query.lte('budget_min', filter.budgetMax!) as dynamic;
        }
        if (filter.startFrom != null) {
          query =
              query.gte('start_date', _dateOnly(filter.startFrom!)) as dynamic;
        }
        if (filter.startTo != null) {
          query =
              query.lte('start_date', _dateOnly(filter.startTo!)) as dynamic;
        }
      }

      // Only "newest" is honored — relevance/nearest are deferred
      // (ts_rank RPC / PostGIS), surfaced as disabled in the UI.
      var ordered = (query as dynamic).order('published_at', ascending: false);
      if (filter?.page != null) {
        final start = filter!.page! * filter.pageSize;
        ordered = ordered.range(start, start + filter.pageSize - 1);
      }
      final data = await ordered as List<dynamic>;
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
