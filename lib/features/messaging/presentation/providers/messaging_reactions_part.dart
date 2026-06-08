part of 'messaging_provider.dart';

/// Reaction actions for [MessagingController], split into a part-file mixin so
/// the controller stays under the file-size budget. Reaches the repository via
/// `ref`, so it needs no controller-private state.
mixin _ReactionActions on Notifier<MessagingState> {
  void _setReactions(String conversationId, List<MessageReaction> reactions) {
    final map = Map<String, List<MessageReaction>>.from(state.reactionsByConvId)
      ..[conversationId] = reactions;
    state = state.copyWith(reactionsByConvId: map);
  }

  /// Toggle my reaction on a message: a new emoji replaces my previous one, the
  /// same emoji removes it. Optimistic; the realtime stream reconciles.
  Future<void> toggleReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    final me = readCurrentUserId(ref);
    if (me == null) return;
    final repo = ref.read(messageRepositoryProvider);
    final current = state.reactionsFor(conversationId);
    final mineNow = current
        .where((r) => r.messageId == messageId && r.userId == me)
        .toList();
    final removing = mineNow.isNotEmpty && mineNow.first.emoji == emoji;

    final optimistic = current
        .where((r) => !(r.messageId == messageId && r.userId == me))
        .toList();
    if (!removing) {
      optimistic.add(
        MessageReaction(
          messageId: messageId,
          conversationId: conversationId,
          userId: me,
          emoji: emoji,
        ),
      );
    }
    _setReactions(conversationId, optimistic);

    final result = removing
        ? await repo.removeReaction(messageId: messageId, userId: me)
        : await repo.setReaction(
            messageId: messageId,
            conversationId: conversationId,
            userId: me,
            emoji: emoji,
          );
    result.fold((f) => state = state.copyWith(error: f.message), (_) {});
  }
}
