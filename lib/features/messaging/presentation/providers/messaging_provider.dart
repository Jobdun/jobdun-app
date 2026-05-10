import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/message_remote_datasource.dart';
import '../../data/repositories/message_repository_impl.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/message_repository.dart';

final _messageDatasourceProvider = Provider<MessageRemoteDataSource>(
  (ref) => MessageRemoteDataSourceImpl(SupabaseConfig.client),
);

final _messageRepositoryProvider = Provider<MessageRepository>(
  (ref) => MessageRepositoryImpl(ref.read(_messageDatasourceProvider)),
);

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
    _repo = ref.read(_messageRepositoryProvider);
    ref.onDispose(_cancelAllSubscriptions);
    return const MessagingState();
  }

  Future<void> loadConversations() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    final result = await _repo.getConversations(userId);
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (convs) {
        state = state.copyWith(
          isLoading: false,
          conversations: convs,
          totalUnread: _computeUnread(convs),
        );
        _startConversationsStream(userId);
      },
    );
  }

  void _startConversationsStream(String userId) {
    _conversationsSub?.cancel();
    _conversationsSub = _repo.watchConversations(userId).listen(
      (convs) {
        state = state.copyWith(
          conversations: convs,
          totalUnread: _computeUnread(convs),
        );
      },
      onError: (Object e) => state = state.copyWith(error: e.toString()),
    );
  }

  Future<void> loadMessages(String conversationId) async {
    final result = await _repo.getMessages(conversationId);
    result.fold(
      (f) => state = state.copyWith(error: f.message),
      (msgs) {
        final updated = Map<String, List<Message>>.from(state.messagesByConvId)
          ..[conversationId] = msgs;
        state = state.copyWith(messagesByConvId: updated);
        _subscribeToMessages(conversationId);
      },
    );
  }

  void _subscribeToMessages(String conversationId) {
    if (_messageSubs.containsKey(conversationId)) return;
    _messageSubs[conversationId] = _repo.watchMessages(conversationId).listen(
      (msgs) {
        final updated = Map<String, List<Message>>.from(state.messagesByConvId)
          ..[conversationId] = msgs;
        state = state.copyWith(messagesByConvId: updated);
      },
      onError: (Object e) => state = state.copyWith(error: e.toString()),
    );
  }

  void unsubscribeMessages(String conversationId) {
    _messageSubs.remove(conversationId)?.cancel();
  }

  Future<void> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    final senderId = SupabaseConfig.client.auth.currentUser?.id;
    if (senderId == null) return;
    final result = await _repo.sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      body: body,
    );
    result.fold(
      (f) => state = state.copyWith(error: f.message),
      (_) {},
    );
  }

  Future<void> markConversationRead(String conversationId) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    final isBuilder =
        ref.read(authControllerProvider).role == UserRole.builder;
    await _repo.markConversationRead(
      conversationId: conversationId,
      userId: userId,
      isBuilder: isBuilder,
    );
  }

  int _computeUnread(List<Conversation> convs) {
    final isBuilder =
        ref.read(authControllerProvider).role == UserRole.builder;
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
  }) =>
      MessagingState(
        conversations: conversations ?? this.conversations,
        messagesByConvId: messagesByConvId ?? this.messagesByConvId,
        totalUnread: totalUnread ?? this.totalUnread,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}
