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
    // Phase D: per-side pin + permanent mute (non-null = on), mirroring the
    // archived_at pattern.
    this.builderPinnedAt,
    this.tradePinnedAt,
    this.builderMutedAt,
    this.tradeMutedAt,
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
  final DateTime? builderPinnedAt;
  final DateTime? tradePinnedAt;
  final DateTime? builderMutedAt;
  final DateTime? tradeMutedAt;
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

  bool isPinnedFor(String userId) =>
      userId == builderId ? builderPinnedAt != null : tradePinnedAt != null;

  bool isMutedFor(String userId) =>
      userId == builderId ? builderMutedAt != null : tradeMutedAt != null;

  /// Sentinel so [copyWith] can SET a nullable timestamp back to null
  /// (unpin/unmute) — a plain nullable parameter can't distinguish
  /// "leave unchanged" from "clear".
  static const Object unset = Object();

  /// Copy limited to the fields the inbox controller mutates optimistically
  /// (pin/mute/unread). Identity + joined display fields always carry over.
  Conversation copyWith({
    Object? builderPinnedAt = unset,
    Object? tradePinnedAt = unset,
    Object? builderMutedAt = unset,
    Object? tradeMutedAt = unset,
    Object? builderLastReadAt = unset,
    Object? tradeLastReadAt = unset,
    int? builderUnreadCount,
    int? tradeUnreadCount,
    ConversationStatus? status,
  }) => Conversation(
    id: id,
    jobId: jobId,
    builderId: builderId,
    tradeId: tradeId,
    lastMessageAt: lastMessageAt,
    lastMessagePreview: lastMessagePreview,
    lastMessageSenderId: lastMessageSenderId,
    builderUnreadCount: builderUnreadCount ?? this.builderUnreadCount,
    tradeUnreadCount: tradeUnreadCount ?? this.tradeUnreadCount,
    builderLastReadAt: builderLastReadAt == unset
        ? this.builderLastReadAt
        : builderLastReadAt as DateTime?,
    tradeLastReadAt: tradeLastReadAt == unset
        ? this.tradeLastReadAt
        : tradeLastReadAt as DateTime?,
    builderPinnedAt: builderPinnedAt == unset
        ? this.builderPinnedAt
        : builderPinnedAt as DateTime?,
    tradePinnedAt: tradePinnedAt == unset
        ? this.tradePinnedAt
        : tradePinnedAt as DateTime?,
    builderMutedAt: builderMutedAt == unset
        ? this.builderMutedAt
        : builderMutedAt as DateTime?,
    tradeMutedAt: tradeMutedAt == unset
        ? this.tradeMutedAt
        : tradeMutedAt as DateTime?,
    status: status ?? this.status,
    createdAt: createdAt,
    otherUserDisplayName: otherUserDisplayName,
    otherUserAvatarUrl: otherUserAvatarUrl,
    jobTitle: jobTitle,
  );

  @override
  List<Object?> get props => [
    id,
    builderId,
    tradeId,
    builderPinnedAt,
    tradePinnedAt,
    builderMutedAt,
    tradeMutedAt,
  ];
}
