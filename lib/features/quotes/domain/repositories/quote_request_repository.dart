import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/quote_request.dart';

abstract interface class QuoteRequestRepository {
  Future<Either<Failure, QuoteRequest>> create({
    required String jobId,
    required String builderId,
    required String tradeId,
    String? requestNote,
  });

  Future<Either<Failure, List<QuoteRequest>>> getReceived(String tradeId);

  Future<Either<Failure, QuoteRequest?>> getForJobTrade(
    String jobId,
    String tradeId,
  );

  Future<Either<Failure, void>> respond({
    required String requestId,
    required double quoteAmount,
    String? responseNote,
  });

  Future<Either<Failure, void>> decline(String requestId);
}
