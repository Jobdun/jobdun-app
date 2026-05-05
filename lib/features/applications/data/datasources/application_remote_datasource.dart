import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/job_application.dart';
import '../models/job_application_model.dart';

abstract interface class ApplicationRemoteDataSource {
  Future<JobApplicationModel> applyToJob({
    required String jobId,
    required String tradeId,
    String? coverMessage,
  });
  Future<List<JobApplicationModel>> getApplicationsForJob(String jobId);
  Future<List<JobApplicationModel>> getMyApplications(String tradeId);
  Future<void> updateStatus(String applicationId, ApplicationStatus status);
  Future<void> withdraw(String applicationId);
}

class ApplicationRemoteDataSourceImpl implements ApplicationRemoteDataSource {
  const ApplicationRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<JobApplicationModel> applyToJob({
    required String jobId,
    required String tradeId,
    String? coverMessage,
  }) async {
    try {
      final data = await _client
          .from('job_applications')
          .insert({'job_id': jobId, 'trade_id': tradeId, 'cover_message': coverMessage})
          .select()
          .single();
      return JobApplicationModel.fromJson(data);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<JobApplicationModel>> getApplicationsForJob(String jobId) async {
    try {
      final data = await _client
          .from('job_applications')
          .select()
          .eq('job_id', jobId);
      return (data as List).map((e) => JobApplicationModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<JobApplicationModel>> getMyApplications(String tradeId) async {
    try {
      final data = await _client
          .from('job_applications')
          .select()
          .eq('trade_id', tradeId);
      return (data as List).map((e) => JobApplicationModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updateStatus(String applicationId, ApplicationStatus status) async {
    try {
      await _client
          .from('job_applications')
          .update({'status': status.name})
          .eq('id', applicationId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> withdraw(String applicationId) async {
    try {
      await _client
          .from('job_applications')
          .update({'status': ApplicationStatus.withdrawn.name})
          .eq('id', applicationId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
