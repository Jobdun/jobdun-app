import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/job.dart';
import '../repositories/job_repository.dart';

class GetJobById {
  const GetJobById(this._repository);
  final JobRepository _repository;

  Future<Either<Failure, Job>> call(String id) => _repository.getJobById(id);
}
