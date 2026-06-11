import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/message_repository.dart';

class MuteConversation {
  const MuteConversation(this._repo);
  final MessageRepository _repo;

  Future<Either<Failure, void>> call({
    required String conversationId,
    required bool isBuilder,
    required bool mute,
  }) => _repo.muteConversation(
    conversationId: conversationId,
    isBuilder: isBuilder,
    mute: mute,
  );
}
