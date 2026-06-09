import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/quote_request.dart';
import '../repositories/quote_request_repository.dart';

class GetQuoteRequestForJobTrade {
  const GetQuoteRequestForJobTrade(this._repo);
  final QuoteRequestRepository _repo;

  Future<Either<Failure, QuoteRequest?>> call(String jobId, String tradeId) =>
      _repo.getForJobTrade(jobId, tradeId);
}
