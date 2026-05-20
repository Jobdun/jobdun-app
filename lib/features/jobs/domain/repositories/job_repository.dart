import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/job.dart';
import '../entities/job_filter.dart';

abstract interface class JobRepository {
  /// Fetch jobs, optionally paginated. When [limit] is null all matching
  /// rows are returned (used by the GetJobs use case and one-shot fetches);
  /// when set, returns the slice `[offset, offset + limit)`.
  Future<Either<Failure, List<Job>>> getJobs({
    JobFilter? filter,
    int? limit,
    int? offset,
  });
  Future<Either<Failure, Job>> getJobById(String id);
  Future<Either<Failure, Job>> createJob(Job job);
  Future<Either<Failure, Job>> updateJob(Job job);
  Future<Either<Failure, void>> softDeleteJob(String id);
  Future<Either<Failure, void>> updateJobStatus(String id, JobStatus status);
  Stream<List<Job>> watchBuilderJobs(String builderId);
}
