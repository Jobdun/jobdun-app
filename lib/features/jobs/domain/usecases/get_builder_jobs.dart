import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/job.dart';
import '../repositories/job_repository.dart';

/// Fetches a builder's own jobs (all statuses, non-deleted). Used by the home
/// "ACTIVE JOBS" tile to count live listings from real rows — replacing the
/// phantom builder_profiles.active_jobs_count column that never existed.
class GetBuilderJobs {
  const GetBuilderJobs(this._repository);
  final JobRepository _repository;

  Future<Either<Failure, List<Job>>> call(String builderId) =>
      _repository.getBuilderJobs(builderId);
}
