import 'package:equatable/equatable.dart';

// Matches schema enum conversation_status
enum ConversationStatus { active, archived, blocked }

extension ConversationStatusX on ConversationStatus {
  String get dbValue => name;
  static ConversationStatus fromDb(String v) =>
      ConversationStatus.values.firstWhere(
        (s) => s.dbValue == v,
        orElse: () => ConversationStatus.active,
      );
}

class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.builderId,
    required this.tradeId,
    required this.status,
    required this.builderUnreadCount,
    required this.tradeUnreadCount,
    required this.createdAt,
    this.jobId,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageSenderId,
    this.builderLastReadAt,
    this.tradeLastReadAt,
    // Joined display fields
    this.otherUserDisplayName,
    this.otherUserAvatarUrl,
    this.jobTitle,
  });

  final String id;
  final String? jobId;
  final String builderId;
  final String tradeId;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? lastMessageSenderId;
  final int builderUnreadCount;
  final int tradeUnreadCount;
  // Read markers (Phase A "Seen"): the timestamp each side last opened the
  // thread. The counterparty's marker drives the sender's Seen indicator.
  final DateTime? builderLastReadAt;
  final DateTime? tradeLastReadAt;
  final ConversationStatus status;
  final DateTime createdAt;

  // Joined from profiles_public and jobs
  final String? otherUserDisplayName;
  final String? otherUserAvatarUrl;
  final String? jobTitle;

  int unreadCountFor(String userId) =>
      userId == builderId ? builderUnreadCount : tradeUnreadCount;

  /// The OTHER participant's last-read timestamp, from [userId]'s point of view.
  /// This is what decides whether [userId]'s sent messages show as "Seen".
  DateTime? otherLastReadAtFor(String userId) =>
      userId == builderId ? tradeLastReadAt : builderLastReadAt;

  @override
  List<Object?> get props => [id, builderId, tradeId];
}
