import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/timesheet.dart';
import '../repositories/timesheet_repository.dart';

class CheckIn {
  const CheckIn(this._repo);
  final TimesheetRepository _repo;

  Future<Either<Failure, Timesheet>> call({
    required String jobId,
    required String builderId,
    required String tradeId,
    double? lat,
    double? lng,
    String? note,
  }) => _repo.checkIn(
    jobId: jobId,
    builderId: builderId,
    tradeId: tradeId,
    lat: lat,
    lng: lng,
    note: note,
  );
}
