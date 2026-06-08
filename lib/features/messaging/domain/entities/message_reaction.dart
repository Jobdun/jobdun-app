import 'package:equatable/equatable.dart';

/// One participant's reaction to one message. One reaction per user per message
/// (DB PK is `(message_id, user_id)`), so a message carries at most two.
class MessageReaction extends Equatable {
  const MessageReaction({
    required this.messageId,
    required this.conversationId,
    required this.userId,
    required this.emoji,
  });

  final String messageId;
  final String conversationId;
  final String userId;
  final String emoji;

  @override
  List<Object?> get props => [messageId, userId, emoji];
}
