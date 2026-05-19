import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/job_application.dart';
import '../repositories/application_repository.dart';

class UpdateApplicationStatus {
  const UpdateApplicationStatus(this._repository);
  final ApplicationRepository _repository;

  Future<Either<Failure, void>> call(
    String applicationId,
    ApplicationStatus status,
  ) => _repository.updateStatus(applicationId, status);
}
