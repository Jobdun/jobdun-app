import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/providers/account_scoped.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/utils/uuid.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/message_remote_datasource.dart';
import '../../data/repositories/message_repository_impl.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/message_reaction.dart';
import '../../domain/repositories/message_repository.dart';
import '../../domain/usecases/get_conversations.dart';
import '../../domain/usecases/get_messages.dart';
import '../../domain/usecases/get_or_create_conversation.dart';
import '../../domain/usecases/send_message.dart';
import '../../domain/usecases/watch_messages.dart';
import '../state/messaging_state.dart';
import '../state/thread_messages.dart';

// How many older messages a history page fetches.
const _pageSize = 30;
// A send that does not confirm within this window is marked failed (retryable).
const _sendTimeout = Duration(seconds: 10);
// Max characters in a single message body. Mirrors the DB-side
// `messages_body_len_chk` constraint (migration 20260608000002).
const kMaxMessageLength = 4000;

// ── Data layer providers (public so tests can override) ───────────────────────
final messageDatasourceProvider = Provider<MessageRemoteDataSource>(
  (ref) => MessageRemoteDataSourceImpl(SupabaseConfig.client),
);

final messageRepositoryProvider = Provider<MessageRepository>(
  (ref) => MessageRepositoryImpl(ref.read(messageDatasourceProvider)),
);

// ── Use cases ─────────────────────────────────────────────────────────────────
// archive / markConversationRead / watchConversation don't have use cases yet —
// they hit the repo directly until one is added. See CLAUDE.md → Engineering
// Standards (documented exception, same as the auth services pattern).
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

// ── Controller ────────────────────────────────────────────────────────────────
final messagingControllerProvider =
    NotifierProvider<MessagingController, MessagingState>(
      MessagingController.new,
    );

class MessagingController extends Notifier<MessagingState>
    with AccountScoped<MessagingState> {
  late MessageRepository _repo;
  StreamSubscription<List<Conversation>>? _conversationsSub;
  final Map<String, StreamSubscription<List<Message>>> _messageSubs = {};
  final Map<String, StreamSubscription<Conversation>> _convRowSubs = {};
  final Map<String, StreamSubscription<List<MessageReaction>>> _reactionSubs =
      {};
  final Set<String> _loadingOlder = {};

  @override
  MessagingState build() {
    _repo = ref.read(messageRepositoryProvider);

    // Clear state on logout or account switch to prevent stale data
    resetOnAccountChange((_) {
      _cancelAllSubscriptions();
      state = const MessagingState();
    });

    ref.onDispose(_cancelAllSubscriptions);
    return const MessagingState();
  }

  Future<void> loadConversations() async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    await _refreshInbox(userId);
    state = state.copyWith(isLoading: false);
    _startConversationsStream(userId);
  }

  // Fetches the inbox via get_inbox(), which resolves the counterparty's
  // display name + the viewer's unread count server-side. The raw realtime
  // stream can't do that join, so we never use its rows directly.
  Future<void> _refreshInbox(String userId) async {
    final result = await ref.read(getConversationsUseCaseProvider).call(userId);
    result.fold(
      (f) => state = state.copyWith(error: f.message),
      (convs) => state = state.copyWith(
        conversations: convs,
        totalUnread: _computeUnread(convs),
      ),
    );
  }

  void _startConversationsStream(String userId) {
    _conversationsSub?.cancel();
    // The stream only signals "a conversation changed" (new message, unread,
    // archive). Re-fetch through get_inbox so names/unread stay resolved —
    // using the stream's raw rows here is what showed "Unknown".
    _conversationsSub = _repo
        .watchConversations(userId)
        .listen(
          (_) => unawaited(_refreshInbox(userId)),
          onError: (Object e) => state = state.copyWith(error: e.toString()),
        );
  }

  /// Loads the most-recent history page, opens the live tail, and starts
  /// watching the conversation row for the counterparty's read marker (Seen).
  Future<void> loadMessages(String conversationId) async {
    final result = await ref
        .read(getMessagesUseCaseProvider)
        .call(conversationId, limit: _pageSize);
    result.fold((f) => state = state.copyWith(error: f.message), (msgs) {
      _mergeConfirmed(conversationId, msgs);
      _setHasMore(conversationId, msgs.length >= _pageSize);
      _subscribeToMessages(conversationId);
      _subscribeToConversation(conversationId);
      _subscribeToReactions(conversationId);
    });
  }

  /// Fetches the page of messages immediately older than the oldest one loaded.
  Future<void> loadOlder(String conversationId) async {
    if (_loadingOlder.contains(conversationId)) return;
    if (!state.hasMoreFor(conversationId)) return;
    final current = state.messagesFor(conversationId);
    if (current.isEmpty) return;

    _loadingOlder.add(conversationId);
    final result = await ref
        .read(getMessagesUseCaseProvider)
        .call(
          conversationId,
          limit: _pageSize,
          before: current.first.createdAt,
        );
    _loadingOlder.remove(conversationId);
    result.fold((f) => state = state.copyWith(error: f.message), (older) {
      _mergeConfirmed(conversationId, older);
      _setHasMore(conversationId, older.length >= _pageSize);
    });
  }

  void _subscribeToMessages(String conversationId) {
    if (_messageSubs.containsKey(conversationId)) return;
    final stream = ref.read(watchMessagesUseCaseProvider).call(conversationId);
    _messageSubs[conversationId] = stream.listen(
      (msgs) => _mergeConfirmed(conversationId, msgs),
      onError: (Object e) => state = state.copyWith(error: e.toString()),
    );
  }

  void _subscribeToConversation(String conversationId) {
    if (_convRowSubs.containsKey(conversationId)) return;
    final me = readCurrentUserId(ref);
    if (me == null) return;
    _convRowSubs[conversationId] = _repo
        .watchConversation(conversationId)
        .listen((conv) {
          final updated = Map<String, DateTime?>.from(
            state.otherLastReadByConvId,
          )..[conversationId] = conv.otherLastReadAtFor(me);
          state = state.copyWith(otherLastReadByConvId: updated);
        }, onError: (_) {});
  }

  void _subscribeToReactions(String conversationId) {
    if (_reactionSubs.containsKey(conversationId)) return;
    _reactionSubs[conversationId] = _repo
        .watchReactions(conversationId)
        .listen(
          (reactions) => _setReactions(conversationId, reactions),
          onError: (_) {},
        );
  }

  void unsubscribeMessages(String conversationId) {
    _messageSubs.remove(conversationId)?.cancel();
    _convRowSubs.remove(conversationId)?.cancel();
    _reactionSubs.remove(conversationId)?.cancel();
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
        ? await _repo.removeReaction(messageId: messageId, userId: me)
        : await _repo.setReaction(
            messageId: messageId,
            conversationId: conversationId,
            userId: me,
            emoji: emoji,
          );
    result.fold((f) => state = state.copyWith(error: f.message), (_) {});
  }

  /// Optimistic send: shows an instant local bubble, inserts with a client_tag,
  /// then lets the realtime echo (matched by client_tag) confirm it. On
  /// failure/timeout the bubble flips to a retryable failed state.
  Future<void> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    final senderId = readCurrentUserId(ref);
    if (senderId == null) return;

    // Text guardrail: trim, reject blank, cap length (mirrors the DB constraint).
    final text = body.trim();
    if (text.isEmpty) return;
    final safe = text.length > kMaxMessageLength
        ? text.substring(0, kMaxMessageLength)
        : text;

    final pending = PendingMessage(
      clientTag: uuidV4(),
      conversationId: conversationId,
      senderId: senderId,
      body: safe,
      createdAt: DateTime.now(),
    );
    _addToOutbox(conversationId, pending);
    await _dispatch(pending);
  }

  /// Re-sends a previously failed outbox message with the same client_tag, so a
  /// duplicate insert is a server-side no-op (idempotent upsert).
  Future<void> retryMessage({
    required String conversationId,
    required String clientTag,
  }) async {
    final matches = state
        .outboxFor(conversationId)
        .where((p) => p.clientTag == clientTag);
    if (matches.isEmpty) return;
    final pending = matches.first;
    _updateOutbox(conversationId, clientTag, failed: false);
    await _dispatch(pending.copyWith(failed: false));
  }

  Future<void> _dispatch(PendingMessage pending) async {
    Either<Failure, void> result;
    try {
      result = await ref
          .read(sendMessageUseCaseProvider)
          .call(
            conversationId: pending.conversationId,
            senderId: pending.senderId,
            body: pending.body,
            clientTag: pending.clientTag,
          )
          .timeout(_sendTimeout);
    } on TimeoutException {
      result = left(ServerFailure('Send timed out'));
    }
    result.fold(
      (_) => _updateOutbox(
        pending.conversationId,
        pending.clientTag,
        failed: true,
      ),
      // Success: leave the outbox entry; the realtime echo prunes it by tag.
      (_) {},
    );
  }

  /// Unsend (soft-delete) one of my messages. Optimistically swaps the bubble
  /// for a tombstone, then persists; reverts if the server rejects.
  Future<void> unsendMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final list = state.messagesFor(conversationId);
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final original = list[idx];

    final optimistic = [...list];
    optimistic[idx] = original.copyWith(deletedAt: DateTime.now());
    _setMessages(conversationId, optimistic);

    final result = await _repo.softDeleteMessage(messageId);
    result.fold((f) {
      final cur = state.messagesFor(conversationId);
      final i = cur.indexWhere((m) => m.id == messageId);
      if (i != -1) {
        final reverted = [...cur]..[i] = original;
        _setMessages(conversationId, reverted);
      }
      state = state.copyWith(error: f.message);
    }, (_) {});
  }

  /// Returns the id of the conversation with the given participants (creating
  /// it if needed), or null on failure. Used by the builder "Message" CTA to
  /// open a thread with an applicant.
  Future<String?> getOrCreateConversation({
    required String builderId,
    required String tradeId,
    String? jobId,
  }) async {
    final result = await ref
        .read(getOrCreateConversationUseCaseProvider)
        .call(builderId: builderId, tradeId: tradeId, jobId: jobId);
    return result.fold((f) {
      state = state.copyWith(error: f.message);
      return null;
    }, (id) => id);
  }

  Future<void> markConversationRead(String conversationId) async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return;
    final isBuilder = ref.read(authControllerProvider).role == UserRole.builder;
    await _repo.markConversationRead(
      conversationId: conversationId,
      userId: userId,
      isBuilder: isBuilder,
    );
  }

  /// Archive a conversation for the current viewer. Builders set
  /// `builder_archived_at`; tradies set `trade_archived_at`. The other
  /// participant still sees the thread until they archive their side
  /// independently. Optimistically removes the row from the in-memory list
  /// so the swipe-confirm feels instant; the realtime watch reconciles if
  /// the server later disagrees.
  Future<void> archiveConversation(String conversationId) async {
    final isBuilder = ref.read(authControllerProvider).role == UserRole.builder;
    final remaining = state.conversations
        .where((c) => c.id != conversationId)
        .toList();
    state = state.copyWith(
      conversations: remaining,
      totalUnread: _computeUnread(remaining),
    );
    final result = await _repo.archiveConversation(
      conversationId: conversationId,
      isBuilder: isBuilder,
    );
    result.fold((f) => state = state.copyWith(error: f.message), (_) {});
  }

  // ── State mutation helpers ──────────────────────────────────────────────────

  /// Unions [incoming] server rows into the conversation's confirmed list
  /// (dedup by id, sorted oldest→newest) and prunes any outbox twins whose
  /// client_tag has now echoed back.
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

  void _setReactions(String conversationId, List<MessageReaction> reactions) {
    final map = Map<String, List<MessageReaction>>.from(state.reactionsByConvId)
      ..[conversationId] = reactions;
    state = state.copyWith(reactionsByConvId: map);
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

  int _computeUnread(List<Conversation> convs) {
    final isBuilder = ref.read(authControllerProvider).role == UserRole.builder;
    return convs.fold<int>(
      0,
      (sum, c) => sum + (isBuilder ? c.builderUnreadCount : c.tradeUnreadCount),
    );
  }

  void _cancelAllSubscriptions() {
    _conversationsSub?.cancel();
    for (final sub in _messageSubs.values) {
      sub.cancel();
    }
    for (final sub in _convRowSubs.values) {
      sub.cancel();
    }
    for (final sub in _reactionSubs.values) {
      sub.cancel();
    }
    _messageSubs.clear();
    _convRowSubs.clear();
    _reactionSubs.clear();
  }
}
