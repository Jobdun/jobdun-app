import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/job.dart';
import '../repositories/job_repository.dart';

class UpdateJob {
  const UpdateJob(this._repository);
  final JobRepository _repository;

  Future<Either<Failure, Job>> call(Job job) => _repository.updateJob(job);
}
