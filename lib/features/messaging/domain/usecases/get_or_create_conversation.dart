import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/message_repository.dart';

/// Returns the id of the conversation between [builderId] and [tradeId]
/// (optionally scoped to [jobId]), creating it if none exists. Backed by the
/// `get_or_create_conversation` RPC, which is atomic and asserts the caller is
/// a participant.
class GetOrCreateConversation {
  const GetOrCreateConversation(this._repository);
  final MessageRepository _repository;

  Future<Either<Failure, String>> call({
    required String builderId,
    required String tradeId,
    String? jobId,
  }) => _repository.getOrCreateConversation(
    builderId: builderId,
    tradeId: tradeId,
    jobId: jobId,
  );
}
