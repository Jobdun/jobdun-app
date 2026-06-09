import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/quote_request_repository.dart';

class RespondToQuoteRequest {
  const RespondToQuoteRequest(this._repo);
  final QuoteRequestRepository _repo;

  Future<Either<Failure, void>> call({
    required String requestId,
    required double quoteAmount,
    String? responseNote,
  }) => _repo.respond(
    requestId: requestId,
    quoteAmount: quoteAmount,
    responseNote: responseNote,
  );
}
