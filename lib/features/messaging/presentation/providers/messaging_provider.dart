import 'dart:async';
import 'dart:io';

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
import '../../domain/usecases/mark_conversation_unread.dart';
import '../../domain/usecases/mute_conversation.dart';
import '../../domain/usecases/pin_conversation.dart';
import '../../domain/usecases/get_messages.dart';
import '../../domain/usecases/get_or_create_conversation.dart';
import '../../domain/usecases/send_message.dart';
import '../../domain/usecases/watch_messages.dart';
import '../state/messaging_state.dart';
import '../state/thread_messages.dart';

part 'messaging_inbox_actions_part.dart';
part 'messaging_reactions_part.dart';

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

// Use-case providers live in messaging_inbox_actions_part.dart (size budget).

// ── Controller ────────────────────────────────────────────────────────────────
final messagingControllerProvider =
    NotifierProvider<MessagingController, MessagingState>(
      MessagingController.new,
    );

class MessagingController extends Notifier<MessagingState>
    with AccountScoped<MessagingState>, _ReactionActions, _InboxActions {
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

  // Inbox via get_inbox() (counterparty + unread resolved server-side); the raw
  // realtime stream can't do that join, so we never use its rows directly.
  @override
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
    // The stream only signals "a conversation changed"; re-fetch through
    // get_inbox so names/unread stay resolved (raw rows showed "Unknown").
    _conversationsSub = _repo
        .watchConversations(userId)
        .listen(
          (_) => unawaited(_refreshInbox(userId)),
          onError: (Object e) => state = state.copyWith(error: e.toString()),
        );
  }

  /// Loads the latest history page, opens the live tail + reaction stream, and
  /// watches the conversation row for the counterparty's read marker (Seen).
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

  /// Optimistic send: instant local bubble, insert with a client_tag, then the
  /// realtime echo confirms it (or it flips to a retryable failed state).
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

  /// Re-sends a failed outbox message with the same client_tag (idempotent).
  Future<void> retryMessage({
    required String conversationId,
    required String clientTag,
  }) async {
    final matches = state
        .outboxFor(conversationId)
        .where((p) => p.clientTag == clientTag);
    if (matches.isEmpty) return;
    final reset = matches.first.copyWith(failed: false);
    _updateOutbox(conversationId, clientTag, failed: false);
    if (reset.isImage && reset.localImagePath != null) {
      await _dispatchImage(reset, File(reset.localImagePath!), null, null);
    } else {
      await _dispatch(reset);
    }
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

  /// Optimistic image send: instant local preview, upload, echo swaps in (or fails).
  Future<void> sendImage({
    required String conversationId,
    required File file,
    required String mime,
    int? width,
    int? height,
  }) async {
    final senderId = readCurrentUserId(ref);
    if (senderId == null) return;
    final pending = PendingMessage(
      clientTag: uuidV4(),
      conversationId: conversationId,
      senderId: senderId,
      body: '',
      createdAt: DateTime.now(),
      localImagePath: file.path,
      mime: mime,
    );
    _addToOutbox(conversationId, pending);
    await _dispatchImage(pending, file, width, height);
  }

  Future<void> _dispatchImage(
    PendingMessage pending,
    File file,
    int? width,
    int? height,
  ) async {
    Either<Failure, void> result;
    try {
      result = await _repo
          .sendImageMessage(
            conversationId: pending.conversationId,
            senderId: pending.senderId,
            clientTag: pending.clientTag,
            file: file,
            mime: pending.mime!,
            width: width,
            height: height,
          )
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      result = left(ServerFailure('Upload timed out'));
    }
    result.fold(
      (_) => _updateOutbox(
        pending.conversationId,
        pending.clientTag,
        failed: true,
      ),
      (_) {},
    );
  }

  /// Unsend (soft-delete) one of my messages. Optimistic tombstone, reverts on
  /// server rejection.
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

  /// Archive a conversation for the current viewer (per-side `*_archived_at`;
  /// the other party still sees it until they archive too). Optimistically
  /// drops it from the list; the realtime watch reconciles.
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

  @override
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
