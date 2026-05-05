import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/job_application.dart';

abstract interface class ApplicationRepository {
  Future<Either<Failure, JobApplication>> applyToJob({
    required String jobId,
    String? coverMessage,
  });
  Future<Either<Failure, List<JobApplication>>> getApplicationsForJob(String jobId);
  Future<Either<Failure, List<JobApplication>>> getMyApplications(String tradeId);
  Future<Either<Failure, void>> updateStatus(
    String applicationId,
    ApplicationStatus status,
  );
  Future<Either<Failure, void>> withdraw(String applicationId);
}
