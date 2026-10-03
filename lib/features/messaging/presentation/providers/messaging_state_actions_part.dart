part of 'messaging_provider.dart';

/// Shared message and optimistic outbox mutations for the controller.
mixin _MessageStateActions on Notifier<MessagingState> {
  // ── State mutation helpers ──────────────────────────────────────────────────

  /// Unions [incoming] server rows into the confirmed list (dedup by id, sorted
  /// oldest→newest) and prunes outbox twins whose client_tag has echoed back.
  void _mergeConfirmed(String conversationId, List<Message> incoming) {
    final byId = <String, Message>{
      for (final m in state.messagesFor(conversationId)) m.id: m,
    };
    for (final m in incoming) {
      byId[m.id] = m;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final messages = Map<String, List<Message>>.from(state.messagesByConvId)
      ..[conversationId] = merged;

    final confirmedTags = merged
        .map((m) => m.clientTag)
        .whereType<String>()
        .toSet();
    final outbox = Map<String, List<PendingMessage>>.from(state.outboxByConvId);
    final remaining = state
        .outboxFor(conversationId)
        .where((p) => !confirmedTags.contains(p.clientTag))
        .toList();
    if (remaining.isEmpty) {
      outbox.remove(conversationId);
    } else {
      outbox[conversationId] = remaining;
    }

    state = state.copyWith(messagesByConvId: messages, outboxByConvId: outbox);
  }

  void _setMessages(String conversationId, List<Message> msgs) {
    final map = Map<String, List<Message>>.from(state.messagesByConvId)
      ..[conversationId] = msgs;
    state = state.copyWith(messagesByConvId: map);
  }

  void _addToOutbox(String conversationId, PendingMessage pending) {
    final outbox = Map<String, List<PendingMessage>>.from(state.outboxByConvId);
    outbox[conversationId] = [...state.outboxFor(conversationId), pending];
    state = state.copyWith(outboxByConvId: outbox);
  }

  void _updateOutbox(
    String conversationId,
    String clientTag, {
    required bool failed,
  }) {
    final current = state.outboxFor(conversationId);
    if (current.every((p) => p.clientTag != clientTag)) return;
    final updated = current
        .map((p) => p.clientTag == clientTag ? p.copyWith(failed: failed) : p)
        .toList();
    final outbox = Map<String, List<PendingMessage>>.from(state.outboxByConvId)
      ..[conversationId] = updated;
    state = state.copyWith(outboxByConvId: outbox);
  }

  void _setHasMore(String conversationId, bool hasMore) {
    final map = Map<String, bool>.from(state.hasMoreByConvId)
      ..[conversationId] = hasMore;
    state = state.copyWith(hasMoreByConvId: map);
  }
}
