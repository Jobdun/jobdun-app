import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/quote_request.dart';
import '../../domain/repositories/quote_request_repository.dart';
import '../datasources/quote_request_remote_datasource.dart';

class QuoteRequestRepositoryImpl implements QuoteRequestRepository {
  const QuoteRequestRepositoryImpl(this._ds);
  final QuoteRequestRemoteDataSource _ds;

  @override
  Future<Either<Failure, QuoteRequest>> create({
    required String jobId,
    required String builderId,
    required String tradeId,
    String? requestNote,
  }) async {
    try {
      final r = await _ds.create(
        jobId: jobId,
        builderId: builderId,
        tradeId: tradeId,
        requestNote: requestNote,
      );
      return Right(r);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<QuoteRequest>>> getReceived(
    String tradeId,
  ) async {
    try {
      return Right(await _ds.getReceived(tradeId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, QuoteRequest?>> getForJobTrade(
    String jobId,
    String tradeId,
  ) async {
    try {
      return Right(await _ds.getForJobTrade(jobId, tradeId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> respond({
    required String requestId,
    required double quoteAmount,
    String? responseNote,
  }) async {
    try {
      await _ds.respond(
        requestId: requestId,
        quoteAmount: quoteAmount,
        responseNote: responseNote,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> decline(String requestId) async {
    try {
      await _ds.decline(requestId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
