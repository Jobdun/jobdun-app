import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/booking.dart';
import '../repositories/booking_repository.dart';

class CreateBooking {
  const CreateBooking(this._repo);
  final BookingRepository _repo;

  Future<Either<Failure, Booking>> call({
    required String jobId,
    required String builderId,
    required String tradeId,
    required DateTime scheduledDate,
    String? note,
  }) => _repo.create(
    jobId: jobId,
    builderId: builderId,
    tradeId: tradeId,
    scheduledDate: scheduledDate,
    note: note,
  );
}
