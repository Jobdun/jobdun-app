import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/message_repository.dart';

class UnblockUser {
  const UnblockUser(this._repo);
  final MessageRepository _repo;

  Future<Either<Failure, void>> call({
    required String blockedId,
    required String conversationId,
  }) => _repo.unblockUser(blockedId: blockedId, conversationId: conversationId);
}
