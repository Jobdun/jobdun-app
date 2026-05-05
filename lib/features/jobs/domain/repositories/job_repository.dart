import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/job.dart';
import '../entities/job_filter.dart';

abstract interface class JobRepository {
  Future<Either<Failure, List<Job>>> getJobs({JobFilter? filter});
  Future<Either<Failure, Job>> getJobById(String id);
  Future<Either<Failure, Job>> createJob(Job job);
  Future<Either<Failure, Job>> updateJob(Job job);
  Future<Either<Failure, void>> deleteJob(String id);
  Future<Either<Failure, void>> updateJobStatus(String id, JobStatus status);
  Stream<List<Job>> watchBuilderJobs(String builderId);
}
