import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/conversation.dart';
import '../entities/message.dart';

abstract interface class MessageRepository {
  Future<Either<Failure, List<Conversation>>> getConversations(String userId);
  Future<Either<Failure, List<Message>>> getMessages(String conversationId);
  Future<Either<Failure, void>> sendMessage({
    required String conversationId,
    required String senderId,
    required String body,
  });
  Future<Either<Failure, void>> markConversationRead({
    required String conversationId,
    required String userId,
    required bool isBuilder,
  });
  Stream<List<Conversation>> watchConversations(String userId);
  Stream<List<Message>> watchMessages(String conversationId);
}
