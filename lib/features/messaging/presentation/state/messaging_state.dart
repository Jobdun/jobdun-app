import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/message_reaction.dart';
import 'thread_messages.dart';

/// Immutable state for [MessagingController]. Extracted from the controller file
/// to keep both under the file-size budget (CLAUDE.md split recipe).
class MessagingState {
  const MessagingState({
    this.conversations = const [],
    this.messagesByConvId = const {},
    this.outboxByConvId = const {},
    this.otherLastReadByConvId = const {},
    this.reactionsByConvId = const {},
    this.hasMoreByConvId = const {},
    this.blockedConvIds = const {},
    this.totalUnread = 0,
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  final List<Conversation> conversations;
  final Map<String, List<Message>> messagesByConvId;
  final Map<String, List<PendingMessage>> outboxByConvId;
  final Map<String, DateTime?> otherLastReadByConvId;
  final Map<String, List<MessageReaction>> reactionsByConvId;
  final Map<String, bool> hasMoreByConvId;

  /// Conversations frozen by a block (either side) — drives the thread's
  /// composer lockout. Fed by the per-thread conversation watch.
  final Set<String> blockedConvIds;

  final int totalUnread;
  final bool isLoading;
  final String? error;

  /// Phase D inbox search — client-side filter over name + preview (D-1).
  final String searchQuery;

  /// What the inbox list renders: all conversations, or the live-filtered
  /// subset while a search query is active.
  List<Conversation> get filteredConversations {
    if (searchQuery.isEmpty) return conversations;
    final q = searchQuery.toLowerCase();
    return conversations.where((c) {
      final name = (c.otherUserDisplayName ?? '').toLowerCase();
      final preview = (c.lastMessagePreview ?? '').toLowerCase();
      return name.contains(q) || preview.contains(q);
    }).toList();
  }

  List<Message> messagesFor(String conversationId) =>
      messagesByConvId[conversationId] ?? const [];

  /// True once a history page has been fetched for [conversationId] (even if it
  /// came back empty) — distinguishes "still loading" from "no messages yet".
  bool isThreadLoaded(String conversationId) =>
      messagesByConvId.containsKey(conversationId);

  List<PendingMessage> outboxFor(String conversationId) =>
      outboxByConvId[conversationId] ?? const [];

  DateTime? otherLastReadFor(String conversationId) =>
      otherLastReadByConvId[conversationId];

  List<MessageReaction> reactionsFor(String conversationId) =>
      reactionsByConvId[conversationId] ?? const [];

  bool hasMoreFor(String conversationId) =>
      hasMoreByConvId[conversationId] ?? false;

  /// The merged, status- and reaction-annotated render list for a conversation.
  List<ThreadEntry> entriesFor(String conversationId, String? me) =>
      buildThreadEntries(
        confirmed: messagesFor(conversationId),
        outbox: outboxFor(conversationId),
        otherLastReadAt: otherLastReadFor(conversationId),
        me: me,
        reactions: reactionsFor(conversationId),
      );

  MessagingState copyWith({
    List<Conversation>? conversations,
    Map<String, List<Message>>? messagesByConvId,
    Map<String, List<PendingMessage>>? outboxByConvId,
    Map<String, DateTime?>? otherLastReadByConvId,
    Map<String, List<MessageReaction>>? reactionsByConvId,
    Map<String, bool>? hasMoreByConvId,
    Set<String>? blockedConvIds,
    int? totalUnread,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) => MessagingState(
    conversations: conversations ?? this.conversations,
    messagesByConvId: messagesByConvId ?? this.messagesByConvId,
    outboxByConvId: outboxByConvId ?? this.outboxByConvId,
    otherLastReadByConvId: otherLastReadByConvId ?? this.otherLastReadByConvId,
    reactionsByConvId: reactionsByConvId ?? this.reactionsByConvId,
    hasMoreByConvId: hasMoreByConvId ?? this.hasMoreByConvId,
    blockedConvIds: blockedConvIds ?? this.blockedConvIds,
    totalUnread: totalUnread ?? this.totalUnread,
    isLoading: isLoading ?? this.isLoading,
    error: error,
    searchQuery: searchQuery ?? this.searchQuery,
  );
}
