import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/job_application.dart';
import '../../domain/repositories/application_repository.dart';
import '../datasources/application_remote_datasource.dart';

class ApplicationRepositoryImpl implements ApplicationRepository {
  const ApplicationRepositoryImpl(this._datasource, this._client);
  final ApplicationRemoteDataSource _datasource;
  final SupabaseClient _client;

  @override
  Future<Either<Failure, JobApplication>> applyToJob({
    required String jobId,
    required String builderId,
    String? coverNote,
    double? quoteAmount,
  }) async {
    try {
      final tradeId = _client.auth.currentUser?.id;
      if (tradeId == null) return left(const AuthFailure('Not authenticated.'));
      final result = await _datasource.applyToJob(
        jobId: jobId,
        tradeId: tradeId,
        builderId: builderId,
        coverNote: coverNote,
        quoteAmount: quoteAmount,
      );
      return right(result);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<JobApplication>>> getMyApplications(
    String tradeId,
  ) async {
    try {
      return right(await _datasource.getMyApplications(tradeId));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<JobApplication>>> getApplicationsForMyJobs(
    String builderId,
  ) async {
    try {
      return right(await _datasource.getApplicationsForMyJobs(builderId));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> updateStatus(
    String applicationId,
    ApplicationStatus status,
  ) async {
    try {
      await _datasource.updateStatus(applicationId, status);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> withdraw(String applicationId) async {
    try {
      await _datasource.withdraw(applicationId);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }
}
