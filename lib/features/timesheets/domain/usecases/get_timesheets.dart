import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/timesheet.dart';
import '../repositories/timesheet_repository.dart';

class GetTimesheets {
  const GetTimesheets(this._repo);
  final TimesheetRepository _repo;

  Future<Either<Failure, List<Timesheet>>> call(String jobId, String tradeId) =>
      _repo.getForJobTrade(jobId, tradeId);
}
