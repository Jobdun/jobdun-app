import 'package:fpdart/fpdart.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/admin_job_filter.dart';
import '../entities/admin_job_row.dart';

abstract class AdminJobsRepository {
  Future<Either<Failure, List<AdminJobRow>>> listJobs({
    required int limit,
    required int offset,
    AdminJobStatusFilter filter = AdminJobStatusFilter.all,
  });

  /// #21a moderation: set a job's lifecycle status (close / cancel / reopen) via
  /// the audited `admin_set_job_status` RPC. Admin-gated in the DB.
  Future<Either<Failure, Unit>> setJobStatus({
    required String jobId,
    required String status,
  });
}
