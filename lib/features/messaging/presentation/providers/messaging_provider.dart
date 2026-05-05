import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';

final messagingControllerProvider =
    NotifierProvider<MessagingController, MessagingState>(
  MessagingController.new,
);

class MessagingController extends Notifier<MessagingState> {
  @override
  MessagingState build() => const MessagingState();
}

class MessagingState {
  const MessagingState({
    this.conversations = const [],
    this.activeMessages = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Conversation> conversations;
  final List<Message> activeMessages;
  final bool isLoading;
  final String? error;

  MessagingState copyWith({
    List<Conversation>? conversations,
    List<Message>? activeMessages,
    bool? isLoading,
    String? error,
  }) =>
      MessagingState(
        conversations: conversations ?? this.conversations,
        activeMessages: activeMessages ?? this.activeMessages,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}
