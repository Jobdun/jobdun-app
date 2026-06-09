import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/booking.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_datasource.dart';

class BookingRepositoryImpl implements BookingRepository {
  const BookingRepositoryImpl(this._ds);
  final BookingRemoteDataSource _ds;

  @override
  Future<Either<Failure, Booking>> create({
    required String jobId,
    required String builderId,
    required String tradeId,
    required DateTime scheduledDate,
    String? note,
  }) async {
    try {
      final b = await _ds.create(
        jobId: jobId,
        builderId: builderId,
        tradeId: tradeId,
        scheduledDate: scheduledDate,
        note: note,
      );
      return Right(b);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Booking>>> getForUser(String userId) async {
    try {
      return Right(await _ds.getForUser(userId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> updateStatus(
    String bookingId,
    BookingStatus status,
  ) async {
    try {
      await _ds.updateStatus(bookingId, status);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
