import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/message_repository.dart';

class SendMessage {
  const SendMessage(this._repository);
  final MessageRepository _repository;

  Future<Either<Failure, void>> call({
    required String conversationId,
    required String senderId,
    required String body,
    required String clientTag,
  }) => _repository.sendMessage(
    conversationId: conversationId,
    senderId: senderId,
    body: body,
    clientTag: clientTag,
  );
}
