import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/admin_job_filter.dart';
import '../entities/admin_job_row.dart';
import '../repositories/admin_jobs_repository.dart';

class ListAdminJobsParams {
  const ListAdminJobsParams({
    required this.limit,
    required this.offset,
    this.filter = AdminJobStatusFilter.all,
  });

  final int limit;
  final int offset;
  final AdminJobStatusFilter filter;
}

class ListAdminJobs {
  const ListAdminJobs(this._repository);

  final AdminJobsRepository _repository;

  Future<Either<Failure, List<AdminJobRow>>> call(ListAdminJobsParams params) {
    return _repository.listJobs(
      limit: params.limit,
      offset: params.offset,
      filter: params.filter,
    );
  }
}
