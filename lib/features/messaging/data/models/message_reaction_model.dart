import '../../domain/entities/message_reaction.dart';

class MessageReactionModel extends MessageReaction {
  const MessageReactionModel({
    required super.messageId,
    required super.conversationId,
    required super.userId,
    required super.emoji,
  });

  factory MessageReactionModel.fromJson(Map<String, dynamic> json) =>
      MessageReactionModel(
        messageId: json['message_id'] as String,
        conversationId: json['conversation_id'] as String,
        userId: json['user_id'] as String,
        emoji: json['emoji'] as String,
      );
}
