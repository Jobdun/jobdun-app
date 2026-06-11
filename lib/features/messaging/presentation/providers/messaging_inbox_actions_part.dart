part of 'messaging_provider.dart';

// ── Use cases ───────────────────────────────────────────────────────────
// archive / markConversationRead / watchConversation hit the repo directly
// (no use case yet) — documented exception, like the auth services pattern.
final getConversationsUseCaseProvider = Provider(
  (ref) => GetConversations(ref.read(messageRepositoryProvider)),
);
final getMessagesUseCaseProvider = Provider(
  (ref) => GetMessages(ref.read(messageRepositoryProvider)),
);
final getOrCreateConversationUseCaseProvider = Provider(
  (ref) => GetOrCreateConversation(ref.read(messageRepositoryProvider)),
);
final sendMessageUseCaseProvider = Provider(
  (ref) => SendMessage(ref.read(messageRepositoryProvider)),
);
final watchMessagesUseCaseProvider = Provider(
  (ref) => WatchMessages(ref.read(messageRepositoryProvider)),
);

// Phase D use-case providers (pin / mute / mark-unread). Block + report live
// in inbox_safety_provider.dart with their own controller.
final pinConversationUseCaseProvider = Provider(
  (ref) => PinConversation(ref.read(messageRepositoryProvider)),
);
final muteConversationUseCaseProvider = Provider(
  (ref) => MuteConversation(ref.read(messageRepositoryProvider)),
);
final markConversationUnreadUseCaseProvider = Provider(
  (ref) => MarkConversationUnread(ref.read(messageRepositoryProvider)),
);

/// Phase D inbox actions for [MessagingController], split into a part-file
/// mixin (same recipe as [_ReactionActions]) so the controller file stays
/// under the size budget. All four actions are optimistic: state flips
/// immediately, the realtime inbox watch / explicit refresh reconciles, and
/// failures roll back via a full refresh.
mixin _InboxActions on Notifier<MessagingState> {
  // Satisfied by MessagingController (same library, so the private names
  // resolve across the part boundary).
  Future<void> _refreshInbox(String userId);
  int _computeUnread(List<Conversation> convs);

  /// Public refresh hook for sibling controllers (InboxSafetyController needs
  /// the inbox to reflect a block without tearing down the streams).
  Future<void> refreshInbox() async {
    final userId = readCurrentUserId(ref);
    if (userId != null) await _refreshInbox(userId);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query.trim());
  }

  bool _isBuilderViewer() =>
      ref.read(authControllerProvider).role == UserRole.builder;

  /// Re-sorts like get_inbox: pinned first (per viewer), then recency.
  List<Conversation> _pinSorted(List<Conversation> convs, String userId) {
    final sorted = [...convs];
    sorted.sort((a, b) {
      final pinCmp = (b.isPinnedFor(userId) ? 1 : 0).compareTo(
        a.isPinnedFor(userId) ? 1 : 0,
      );
      if (pinCmp != 0) return pinCmp;
      final at = a.lastMessageAt ?? a.createdAt;
      final bt = b.lastMessageAt ?? b.createdAt;
      return bt.compareTo(at);
    });
    return sorted;
  }

  Future<void> pinConversation(
    String conversationId, {
    required bool pin,
  }) async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return;
    final isBuilder = _isBuilderViewer();
    final stamp = pin ? DateTime.now() : null;
    final updated = state.conversations
        .map(
          (c) => c.id != conversationId
              ? c
              : (isBuilder
                    ? c.copyWith(builderPinnedAt: stamp)
                    : c.copyWith(tradePinnedAt: stamp)),
        )
        .toList();
    state = state.copyWith(conversations: _pinSorted(updated, userId));
    final result = await ref
        .read(pinConversationUseCaseProvider)
        .call(conversationId: conversationId, isBuilder: isBuilder, pin: pin);
    result.fold((f) {
      state = state.copyWith(error: f.message);
      unawaited(_refreshInbox(userId));
    }, (_) {});
  }

  Future<void> muteConversation(
    String conversationId, {
    required bool mute,
  }) async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return;
    final isBuilder = _isBuilderViewer();
    final stamp = mute ? DateTime.now() : null;
    final updated = state.conversations
        .map(
          (c) => c.id != conversationId
              ? c
              : (isBuilder
                    ? c.copyWith(builderMutedAt: stamp)
                    : c.copyWith(tradeMutedAt: stamp)),
        )
        .toList();
    state = state.copyWith(conversations: updated);
    final result = await ref
        .read(muteConversationUseCaseProvider)
        .call(conversationId: conversationId, isBuilder: isBuilder, mute: mute);
    result.fold((f) {
      state = state.copyWith(error: f.message);
      unawaited(_refreshInbox(userId));
    }, (_) {});
  }

  /// Mark-unread sentinel (D-6): viewer's last-read cleared + badge of 1.
  Future<void> markConversationUnread(String conversationId) async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return;
    final isBuilder = _isBuilderViewer();
    final updated = state.conversations
        .map(
          (c) => c.id != conversationId
              ? c
              : (isBuilder
                    ? c.copyWith(builderLastReadAt: null, builderUnreadCount: 1)
                    : c.copyWith(tradeLastReadAt: null, tradeUnreadCount: 1)),
        )
        .toList();
    state = state.copyWith(
      conversations: updated,
      totalUnread: _computeUnread(updated),
    );
    final result = await ref
        .read(markConversationUnreadUseCaseProvider)
        .call(conversationId: conversationId, isBuilder: isBuilder);
    result.fold((f) {
      state = state.copyWith(error: f.message);
      unawaited(_refreshInbox(userId));
    }, (_) {});
  }
}
