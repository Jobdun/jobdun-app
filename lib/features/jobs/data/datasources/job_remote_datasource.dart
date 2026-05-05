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
  Future<void> deleteJob(String id);
  Future<void> updateJobStatus(String id, JobStatus status);
  Stream<List<JobModel>> watchBuilderJobs(String builderId);
}

class JobRemoteDataSourceImpl implements JobRemoteDataSource {
  const JobRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<List<JobModel>> getJobs({JobFilter? filter}) async {
    try {
      var query = _client.from('jobs').select();
      if (filter != null && !filter.isEmpty) {
        if (filter.status != null) {
          query = query.eq('status', filter.status!.dbValue) as dynamic;
        }
        if (filter.tradeCategory != null) {
          query = query.eq('trade_category', filter.tradeCategory!) as dynamic;
        }
      }
      final data = await query as List<dynamic>;
      return data.map((e) => JobModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<JobModel> getJobById(String id) async {
    try {
      final data = await _client.from('jobs').select().eq('id', id).single();
      return JobModel.fromJson(data);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<JobModel> createJob(JobModel job) async {
    try {
      final json = job.toJson()..remove('id');
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

  @override
  Future<void> deleteJob(String id) async {
    try {
      await _client.from('jobs').delete().eq('id', id);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updateJobStatus(String id, JobStatus status) async {
    try {
      await _client
          .from('jobs')
          .update({'status': status.dbValue})
          .eq('id', id);
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
        .map((rows) => rows.map(JobModel.fromJson).toList());
  }
}
