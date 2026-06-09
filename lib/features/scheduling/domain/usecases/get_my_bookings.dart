import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/booking.dart';
import '../repositories/booking_repository.dart';

class GetMyBookings {
  const GetMyBookings(this._repo);
  final BookingRepository _repo;

  Future<Either<Failure, List<Booking>>> call(String userId) =>
      _repo.getForUser(userId);
}
