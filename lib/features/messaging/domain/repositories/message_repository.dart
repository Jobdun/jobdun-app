import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/conversation.dart';
import '../entities/message.dart';

abstract interface class MessageRepository {
  Future<Either<Failure, void>> sendMessage(Message message);
  Future<Either<Failure, List<Message>>> getMessages({
    required String jobId,
    required String otherUserId,
  });
  Future<Either<Failure, List<Conversation>>> getConversations(String userId);
  Future<Either<Failure, void>> markAsRead(String messageId);
  Stream<List<Message>> watchMessages({
    required String jobId,
    required String otherUserId,
  });
}
