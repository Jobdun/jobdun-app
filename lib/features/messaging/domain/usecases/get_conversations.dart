import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/conversation.dart';
import '../repositories/message_repository.dart';

class GetConversations {
  const GetConversations(this._repository);
  final MessageRepository _repository;

  Future<Either<Failure, List<Conversation>>> call(String userId) =>
      _repository.getConversations(userId);
}
