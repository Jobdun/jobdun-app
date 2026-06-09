import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/timesheet.dart';

abstract interface class TimesheetRepository {
  Future<Either<Failure, Timesheet>> checkIn({
    required String jobId,
    required String builderId,
    required String tradeId,
    double? lat,
    double? lng,
    String? note,
  });

  Future<Either<Failure, void>> checkOut({
    required String timesheetId,
    double? lat,
    double? lng,
  });

  Future<Either<Failure, List<Timesheet>>> getForJobTrade(
    String jobId,
    String tradeId,
  );
}
