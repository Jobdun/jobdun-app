import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/job_filter.dart';
import '../../domain/repositories/job_repository.dart';
import '../datasources/job_remote_datasource.dart';
import '../models/job_model.dart';

class JobRepositoryImpl implements JobRepository {
  const JobRepositoryImpl(this._datasource);
  final JobRemoteDataSource _datasource;

  @override
  Future<Either<Failure, List<Job>>> getJobs({
    JobFilter? filter,
    int? limit,
    int? offset,
  }) async {
    try {
      return right(
        await _datasource.getJobs(filter: filter, limit: limit, offset: offset),
      );
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Job>> getJobById(String id) async {
    try {
      return right(await _datasource.getJobById(id));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Job>> createJob(Job job) async {
    try {
      final model = job is JobModel ? job : JobModel.fromEntity(job);
      return right(await _datasource.createJob(model));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Job>> updateJob(Job job) async {
    try {
      final model = job is JobModel ? job : JobModel.fromEntity(job);
      return right(await _datasource.updateJob(model));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> softDeleteJob(String id) async {
    try {
      await _datasource.softDeleteJob(id);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> updateJobStatus(
    String id,
    JobStatus status,
  ) async {
    try {
      await _datasource.updateJobStatus(id, status);
      return right(null);
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }

  @override
  Stream<List<Job>> watchBuilderJobs(String builderId) =>
      _datasource.watchBuilderJobs(builderId);
}
