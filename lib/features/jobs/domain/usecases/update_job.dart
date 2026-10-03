import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/job.dart';
import '../repositories/job_repository.dart';
import 'validate_job.dart';

class UpdateJob {
  const UpdateJob(this._repository);
  final JobRepository _repository;

  Future<Either<Failure, Job>> call(Job job) async {
    final error = validateJob(job);
    if (error != null) return Left(ValidationFailure(error));
    return _repository.updateJob(job);
  }
}
