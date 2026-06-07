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
import '../../domain/repositories/message_repository.dart';
import '../../domain/usecases/get_conversations.dart';
import '../../domain/usecases/get_messages.dart';
import '../../domain/usecases/get_or_create_conversation.dart';
import '../../domain/usecases/send_message.dart';
import '../../domain/usecases/watch_messages.dart';
import '../state/thread_messages.dart';

// How many older messages a history page fetches.
const _pageSize = 30;
// A send that does not confirm within this window is marked failed (retryable).
const _sendTimeout = Duration(seconds: 10);

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

  void unsubscribeMessages(String conversationId) {
    _messageSubs.remove(conversationId)?.cancel();
    _convRowSubs.remove(conversationId)?.cancel();
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

    final pending = PendingMessage(
      clientTag: uuidV4(),
      conversationId: conversationId,
      senderId: senderId,
      body: body,
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
    _messageSubs.clear();
    _convRowSubs.clear();
  }
}

class MessagingState {
  const MessagingState({
    this.conversations = const [],
    this.messagesByConvId = const {},
    this.outboxByConvId = const {},
    this.otherLastReadByConvId = const {},
    this.hasMoreByConvId = const {},
    this.totalUnread = 0,
    this.isLoading = false,
    this.error,
  });

  final List<Conversation> conversations;
  final Map<String, List<Message>> messagesByConvId;
  final Map<String, List<PendingMessage>> outboxByConvId;
  final Map<String, DateTime?> otherLastReadByConvId;
  final Map<String, bool> hasMoreByConvId;
  final int totalUnread;
  final bool isLoading;
  final String? error;

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

  bool hasMoreFor(String conversationId) =>
      hasMoreByConvId[conversationId] ?? false;

  /// The merged, status-annotated render list for a conversation.
  List<ThreadEntry> entriesFor(String conversationId, String? me) =>
      buildThreadEntries(
        confirmed: messagesFor(conversationId),
        outbox: outboxFor(conversationId),
        otherLastReadAt: otherLastReadFor(conversationId),
        me: me,
      );

  MessagingState copyWith({
    List<Conversation>? conversations,
    Map<String, List<Message>>? messagesByConvId,
    Map<String, List<PendingMessage>>? outboxByConvId,
    Map<String, DateTime?>? otherLastReadByConvId,
    Map<String, bool>? hasMoreByConvId,
    int? totalUnread,
    bool? isLoading,
    String? error,
  }) => MessagingState(
    conversations: conversations ?? this.conversations,
    messagesByConvId: messagesByConvId ?? this.messagesByConvId,
    outboxByConvId: outboxByConvId ?? this.outboxByConvId,
    otherLastReadByConvId: otherLastReadByConvId ?? this.otherLastReadByConvId,
    hasMoreByConvId: hasMoreByConvId ?? this.hasMoreByConvId,
    totalUnread: totalUnread ?? this.totalUnread,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}
