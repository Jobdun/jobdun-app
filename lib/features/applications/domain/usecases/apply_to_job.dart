import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/job_application.dart';
import '../repositories/application_repository.dart';

class ApplyToJob {
  const ApplyToJob(this._repository);
  final ApplicationRepository _repository;

  Future<Either<Failure, JobApplication>> call({
    required String jobId,
    required String builderId,
    String? coverNote,
    double? proposedRate,
    String? proposedRateType,
  }) => _repository.applyToJob(
    jobId: jobId,
    builderId: builderId,
    coverNote: coverNote,
    proposedRate: proposedRate,
    proposedRateType: proposedRateType,
  );
}
