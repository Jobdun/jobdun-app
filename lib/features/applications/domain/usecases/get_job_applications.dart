import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/job_application.dart';
import '../repositories/application_repository.dart';

class GetJobApplications {
  const GetJobApplications(this._repository);
  final ApplicationRepository _repository;

  Future<Either<Failure, List<JobApplication>>> call(String jobId) =>
      _repository.getApplicationsForJob(jobId);
}
