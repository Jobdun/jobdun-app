import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/quote_request_repository.dart';

class DeclineQuoteRequest {
  const DeclineQuoteRequest(this._repo);
  final QuoteRequestRepository _repo;

  Future<Either<Failure, void>> call(String requestId) =>
      _repo.decline(requestId);
}
