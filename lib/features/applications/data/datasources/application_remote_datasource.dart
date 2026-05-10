import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/job_application.dart';
import '../models/job_application_model.dart';

abstract interface class ApplicationRemoteDataSource {
  Future<JobApplicationModel> applyToJob({
    required String jobId,
    required String tradeId,
    required String builderId,
    String? coverNote,
    double? proposedRate,
    String? proposedRateType,
  });
  Future<List<JobApplicationModel>> getMyApplications(String tradeId);
  Future<List<JobApplicationModel>> getApplicationsForMyJobs(String builderId);
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
    required String builderId,
    String? coverNote,
    double? proposedRate,
    String? proposedRateType,
  }) async {
    try {
      final data = await _client
          .from('applications')
          .insert({
            'job_id': jobId,
            'trade_id': tradeId,
            'builder_id': builderId,
            // ignore: use_null_aware_elements
            if (coverNote != null) 'cover_note': coverNote,
            // ignore: use_null_aware_elements
            if (proposedRate != null) 'proposed_rate': proposedRate,
            // ignore: use_null_aware_elements
            if (proposedRateType != null) 'proposed_rate_type': proposedRateType,
          })
          .select()
          .single();
      return JobApplicationModel.fromJson(data);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<JobApplicationModel>> getMyApplications(String tradeId) async {
    try {
      final data = await _client
          .from('applications')
          .select('*, jobs(title, suburb, state, status), builder_profiles(company_name)')
          .eq('trade_id', tradeId)
          .order('created_at', ascending: false);
      return (data as List).map((e) => JobApplicationModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<JobApplicationModel>> getApplicationsForMyJobs(String builderId) async {
    try {
      final data = await _client
          .from('applications')
          .select('*, trade_profiles(full_name, primary_trade, is_verified), jobs(title, suburb, state)')
          .eq('builder_id', builderId)
          .order('created_at', ascending: false);
      return (data as List).map((e) => JobApplicationModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> updateStatus(String applicationId, ApplicationStatus status) async {
    try {
      await _client
          .from('applications')
          .update({
            'status': status.dbValue,
            'status_changed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', applicationId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> withdraw(String applicationId) async {
    try {
      await _client
          .from('applications')
          .update({
            'status': ApplicationStatus.withdrawn.dbValue,
            'status_changed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', applicationId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
