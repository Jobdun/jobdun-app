import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/quote_request.dart';
import '../repositories/quote_request_repository.dart';

class CreateQuoteRequest {
  const CreateQuoteRequest(this._repo);
  final QuoteRequestRepository _repo;

  Future<Either<Failure, QuoteRequest>> call({
    required String jobId,
    required String builderId,
    required String tradeId,
    String? requestNote,
  }) => _repo.create(
    jobId: jobId,
    builderId: builderId,
    tradeId: tradeId,
    requestNote: requestNote,
  );
}
