import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/message_repository.dart';

class MarkConversationUnread {
  const MarkConversationUnread(this._repo);
  final MessageRepository _repo;

  Future<Either<Failure, void>> call({
    required String conversationId,
    required bool isBuilder,
  }) => _repo.markConversationUnread(
    conversationId: conversationId,
    isBuilder: isBuilder,
  );
}
