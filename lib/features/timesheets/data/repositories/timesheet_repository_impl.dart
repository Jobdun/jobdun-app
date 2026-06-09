import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/timesheet.dart';
import '../../domain/repositories/timesheet_repository.dart';
import '../datasources/timesheet_remote_datasource.dart';

class TimesheetRepositoryImpl implements TimesheetRepository {
  const TimesheetRepositoryImpl(this._ds);
  final TimesheetRemoteDataSource _ds;

  @override
  Future<Either<Failure, Timesheet>> checkIn({
    required String jobId,
    required String builderId,
    required String tradeId,
    double? lat,
    double? lng,
    String? note,
  }) async {
    try {
      final t = await _ds.checkIn(
        jobId: jobId,
        builderId: builderId,
        tradeId: tradeId,
        lat: lat,
        lng: lng,
        note: note,
      );
      return Right(t);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> checkOut({
    required String timesheetId,
    double? lat,
    double? lng,
  }) async {
    try {
      await _ds.checkOut(timesheetId: timesheetId, lat: lat, lng: lng);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Timesheet>>> getForJobTrade(
    String jobId,
    String tradeId,
  ) async {
    try {
      return Right(await _ds.getForJobTrade(jobId, tradeId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
