import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/job.dart';
import '../../domain/repositories/job_interactions_repository.dart';
import '../datasources/job_interactions_datasource.dart';

class JobInteractionsRepositoryImpl implements JobInteractionsRepository {
  const JobInteractionsRepositoryImpl(this._datasource);
  final JobInteractionsDataSource _datasource;

  @override
  Future<Either<Failure, void>> saveJob(String userId, String jobId) async {
    try {
      await _datasource.saveJob(userId, jobId);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> unsaveJob(String userId, String jobId) async {
    try {
      await _datasource.unsaveJob(userId, jobId);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> hideJob(String userId, String jobId) async {
    try {
      await _datasource.hideJob(userId, jobId);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Set<String>>> getSavedJobIds(String userId) async {
    try {
      return right(await _datasource.getSavedJobIds(userId));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Set<String>>> getHiddenJobIds(String userId) async {
    try {
      return right(await _datasource.getHiddenJobIds(userId));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Job>>> getSavedJobs(String userId) async {
    try {
      return right(await _datasource.getSavedJobs(userId));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }
}
