import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/conversation.dart';
import '../entities/message.dart';

abstract interface class MessageRepository {
  Future<Either<Failure, List<Conversation>>> getConversations(String userId);
  Future<Either<Failure, String>> getOrCreateConversation({
    required String builderId,
    required String tradeId,
    String? jobId,
  });
  Future<Either<Failure, List<Message>>> getMessages(
    String conversationId, {
    int? limit,
    DateTime? before,
  });
  Future<Either<Failure, void>> sendMessage({
    required String conversationId,
    required String senderId,
    required String body,
    required String clientTag,
  });
  Future<Either<Failure, void>> softDeleteMessage(String messageId);
  Future<Either<Failure, void>> markConversationRead({
    required String conversationId,
    required String userId,
    required bool isBuilder,
  });
  Future<Either<Failure, void>> archiveConversation({
    required String conversationId,
    required bool isBuilder,
  });
  Stream<List<Conversation>> watchConversations(String userId);
  Stream<List<Message>> watchMessages(String conversationId, {int tailLimit});
  Stream<Conversation> watchConversation(String conversationId);
}
