import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/booking.dart';

abstract interface class BookingRepository {
  Future<Either<Failure, Booking>> create({
    required String jobId,
    required String builderId,
    required String tradeId,
    required DateTime scheduledDate,
    String? note,
  });

  Future<Either<Failure, List<Booking>>> getForUser(String userId);

  Future<Either<Failure, void>> updateStatus(
    String bookingId,
    BookingStatus status,
  );
}
