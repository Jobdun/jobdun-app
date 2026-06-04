import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/current_user_provider.dart';
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

// ── Data layer providers (public so tests can override) ───────────────────────
final messageDatasourceProvider = Provider<MessageRemoteDataSource>(
  (ref) => MessageRemoteDataSourceImpl(SupabaseConfig.client),
);

final messageRepositoryProvider = Provider<MessageRepository>(
  (ref) => MessageRepositoryImpl(ref.read(messageDatasourceProvider)),
);

// ── Use cases ─────────────────────────────────────────────────────────────────
// archive / markConversationRead don't have use cases yet — they hit the repo
// directly until one is added. See CLAUDE.md → Engineering Standards.
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

class MessagingController extends Notifier<MessagingState> {
  late MessageRepository _repo;
  StreamSubscription<List<Conversation>>? _conversationsSub;
  final Map<String, StreamSubscription<List<Message>>> _messageSubs = {};

  @override
  MessagingState build() {
    _repo = ref.read(messageRepositoryProvider);

    // Clear state on logout or account switch to prevent stale data
    ref.listen(currentUserIdProvider, (previous, next) {
      if (next.value == null ||
          (previous?.value != null && previous?.value != next.value)) {
        _cancelAllSubscriptions();
        state = const MessagingState();
      }
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

  Future<void> loadMessages(String conversationId) async {
    final result = await ref
        .read(getMessagesUseCaseProvider)
        .call(conversationId);
    result.fold((f) => state = state.copyWith(error: f.message), (msgs) {
      final updated = Map<String, List<Message>>.from(state.messagesByConvId)
        ..[conversationId] = msgs;
      state = state.copyWith(messagesByConvId: updated);
      _subscribeToMessages(conversationId);
    });
  }

  void _subscribeToMessages(String conversationId) {
    if (_messageSubs.containsKey(conversationId)) return;
    final stream = ref.read(watchMessagesUseCaseProvider).call(conversationId);
    _messageSubs[conversationId] = stream.listen((msgs) {
      final updated = Map<String, List<Message>>.from(state.messagesByConvId)
        ..[conversationId] = msgs;
      state = state.copyWith(messagesByConvId: updated);
    }, onError: (Object e) => state = state.copyWith(error: e.toString()));
  }

  void unsubscribeMessages(String conversationId) {
    _messageSubs.remove(conversationId)?.cancel();
  }

  Future<void> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    final senderId = readCurrentUserId(ref);
    if (senderId == null) return;
    final result = await ref
        .read(sendMessageUseCaseProvider)
        .call(conversationId: conversationId, senderId: senderId, body: body);
    result.fold((f) => state = state.copyWith(error: f.message), (_) {});
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
    _messageSubs.clear();
  }
}

class MessagingState {
  const MessagingState({
    this.conversations = const [],
    this.messagesByConvId = const {},
    this.totalUnread = 0,
    this.isLoading = false,
    this.error,
  });

  final List<Conversation> conversations;
  final Map<String, List<Message>> messagesByConvId;
  final int totalUnread;
  final bool isLoading;
  final String? error;

  List<Message> messagesFor(String conversationId) =>
      messagesByConvId[conversationId] ?? const [];

  MessagingState copyWith({
    List<Conversation>? conversations,
    Map<String, List<Message>>? messagesByConvId,
    int? totalUnread,
    bool? isLoading,
    String? error,
  }) => MessagingState(
    conversations: conversations ?? this.conversations,
    messagesByConvId: messagesByConvId ?? this.messagesByConvId,
    totalUnread: totalUnread ?? this.totalUnread,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}
