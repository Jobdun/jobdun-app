import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/job_application.dart';

abstract interface class ApplicationRepository {
  Future<Either<Failure, JobApplication>> applyToJob({
    required String jobId,
    required String builderId,
    String? coverNote,
    double? quoteAmount,
  });
  Future<Either<Failure, List<JobApplication>>> getMyApplications(
    String tradeId,
  );
  Future<Either<Failure, List<JobApplication>>> getApplicationsForMyJobs(
    String builderId,
  );
  Future<Either<Failure, void>> updateStatus(
    String applicationId,
    ApplicationStatus status,
  );
  Future<Either<Failure, void>> withdraw(String applicationId);
}
