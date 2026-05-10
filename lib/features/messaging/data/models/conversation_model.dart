import '../../domain/entities/conversation.dart';

class ConversationModel extends Conversation {
  const ConversationModel({
    required super.id,
    required super.builderId,
    required super.tradeId,
    required super.status,
    required super.builderUnreadCount,
    required super.tradeUnreadCount,
    required super.createdAt,
    super.jobId,
    super.lastMessageAt,
    super.lastMessagePreview,
    super.lastMessageSenderId,
    super.otherUserDisplayName,
    super.otherUserAvatarUrl,
    super.jobTitle,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final profileData = json['profiles_public'] as Map<String, dynamic>?;
    final jobData = json['jobs'] as Map<String, dynamic>?;

    return ConversationModel(
      id: json['id'] as String,
      jobId: json['job_id'] as String?,
      builderId: json['builder_id'] as String,
      tradeId: json['trade_id'] as String,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      builderUnreadCount: json['builder_unread_count'] as int? ?? 0,
      tradeUnreadCount: json['trade_unread_count'] as int? ?? 0,
      status: ConversationStatusX.fromDb(json['status'] as String? ?? 'active'),
      createdAt: DateTime.parse(json['created_at'] as String),
      otherUserDisplayName: profileData?['display_name'] as String?,
      otherUserAvatarUrl: profileData?['avatar_url'] as String?,
      jobTitle: jobData?['title'] as String?,
    );
  }
}
