import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/quote_request.dart';
import '../repositories/quote_request_repository.dart';

class GetReceivedQuoteRequests {
  const GetReceivedQuoteRequests(this._repo);
  final QuoteRequestRepository _repo;

  Future<Either<Failure, List<QuoteRequest>>> call(String tradeId) =>
      _repo.getReceived(tradeId);
}
