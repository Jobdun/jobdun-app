import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/message_repository.dart';

class BlockUser {
  const BlockUser(this._repo);
  final MessageRepository _repo;

  Future<Either<Failure, void>> call({
    required String blockerId,
    required String blockedId,
    required String conversationId,
  }) => _repo.blockUser(
    blockerId: blockerId,
    blockedId: blockedId,
    conversationId: conversationId,
  );
}
