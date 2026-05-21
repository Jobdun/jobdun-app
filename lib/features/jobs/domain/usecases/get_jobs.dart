import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/job.dart';
import '../entities/job_filter.dart';
import '../repositories/job_repository.dart';

class GetJobs {
  const GetJobs(this._repository);
  final JobRepository _repository;

  Future<Either<Failure, List<Job>>> call({
    JobFilter? filter,
    int? limit,
    int? offset,
  }) => _repository.getJobs(filter: filter, limit: limit, offset: offset);
}
