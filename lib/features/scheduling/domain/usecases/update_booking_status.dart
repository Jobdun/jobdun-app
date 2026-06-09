import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/booking.dart';
import '../repositories/booking_repository.dart';

class UpdateBookingStatus {
  const UpdateBookingStatus(this._repo);
  final BookingRepository _repo;

  Future<Either<Failure, void>> call(String bookingId, BookingStatus status) =>
      _repo.updateStatus(bookingId, status);
}
