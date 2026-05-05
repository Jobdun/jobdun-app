import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/job_repository.dart';

class DeleteJob {
  const DeleteJob(this._repository);
  final JobRepository _repository;

  Future<Either<Failure, void>> call(String id) => _repository.deleteJob(id);
}
