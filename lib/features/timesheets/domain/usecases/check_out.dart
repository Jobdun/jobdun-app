import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/timesheet_repository.dart';

class CheckOut {
  const CheckOut(this._repo);
  final TimesheetRepository _repo;

  Future<Either<Failure, void>> call({
    required String timesheetId,
    double? lat,
    double? lng,
  }) => _repo.checkOut(timesheetId: timesheetId, lat: lat, lng: lng);
}
