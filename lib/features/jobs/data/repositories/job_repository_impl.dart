import 'package:fpdart/fpdart.dart';

import '../../../../core/cache/cache_store.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/job_filter.dart';
import '../../domain/repositories/job_repository.dart';
import '../datasources/job_remote_datasource.dart';
import '../models/job_model.dart';

class JobRepositoryImpl implements JobRepository {
  const JobRepositoryImpl(this._datasource, this._cache);
  final JobRemoteDataSource _datasource;
  final CacheStore _cache;

  // Bump either when JobModel's cache shape changes — old entries then purge on
  // read instead of mis-deserializing (docs/CACHING_ARCHITECTURE.md §3.3).
  static const _builderJobsCacheVersion = 1;
  static const _openJobsCacheVersion = 1;
  static const _openJobsFirstPageKey = 'open_jobs:first';
  String _builderJobsKey(String builderId) => 'builder_jobs:$builderId';

  @override
  Future<Either<Failure, List<Job>>> getJobs({
    JobFilter? filter,
    int? limit,
    int? offset,
  }) async {
    // Only the default, unfiltered first page is cached for offline (the home +
    // jobs-tab landing view). Filtered / paged queries fetch live and fail
    // offline as before — caching every combination isn't worth it (doc §3.1).
    final isFirstPage =
        (offset == null || offset == 0) && (filter == null || filter.isEmpty);
    try {
      final jobs = await _datasource.getJobs(
        filter: filter,
        limit: limit,
        offset: offset,
      );
      if (isFirstPage) {
        await _cache.write(
          _openJobsFirstPageKey,
          jobs.map((j) => j.toCacheMap()).toList(),
          schemaVersion: _openJobsCacheVersion,
        );
      }
      return right(jobs);
    } on ServerException catch (e) {
      if (isFirstPage) {
        final cached = await _cache.read(
          _openJobsFirstPageKey,
          schemaVersion: _openJobsCacheVersion,
        );
        if (cached != null) {
          final rows = (cached.payload as List).cast<Map<String, dynamic>>();
          return right(rows.map<Job>(JobModel.fromJson).toList());
        }
      }
      return left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Job>>> getBuilderJobs(String builderId) async {
    final key = _builderJobsKey(builderId);
    try {
      final jobs = await _datasource.getBuilderJobs(builderId);
      // Write-through: persist last-known so a later offline open isn't blank.
      await _cache.write(
        key,
        jobs.map((j) => j.toCacheMap()).toList(),
        schemaVersion: _builderJobsCacheVersion,
      );
      return right(jobs);
    } on ServerException catch (e) {
      // Offline / server error: serve last-known from disk if we have it.
      final cached = await _cache.read(
        key,
        schemaVersion: _builderJobsCacheVersion,
      );
      if (cached != null) {
        final rows = (cached.payload as List).cast<Map<String, dynamic>>();
        return right(rows.map<Job>(JobModel.fromJson).toList());
      }
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
