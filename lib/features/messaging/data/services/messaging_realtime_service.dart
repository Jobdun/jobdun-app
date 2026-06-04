import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/conversation_typing.dart';

/// Ephemeral realtime channels for messaging: a global online-presence channel
/// and a per-conversation typing broadcast. A RealtimeChannel is a stateful
/// client (not a queryable repository), so this lives in data/services like the
/// auth services — the provider file wires it in.
class MessagingRealtimeService {
  const MessagingRealtimeService(this._client);

  final SupabaseClient _client;

  /// Joins the global presence channel (tracking [myUserId]) and emits the set
  /// of currently-online user ids. The channel is removed when the returned
  /// stream is cancelled (e.g. the last listener goes away).
  Stream<Set<String>> onlineUserIds(String myUserId) {
    final channel = _client.channel('online-users');
    final controller = StreamController<Set<String>>();
    controller.onCancel = () => _client.removeChannel(channel);

    void emit() {
      final ids = channel
          .presenceState()
          .expand((s) => s.presences)
          .map((p) => p.payload['user_id'] as String?)
          .whereType<String>()
          .toSet();
      if (!controller.isClosed) controller.add(ids);
    }

    channel.onPresenceSync((_, [_]) => emit()).subscribe((status, [_]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await channel.track({'user_id': myUserId});
      }
    });
    return controller.stream;
  }

  /// Opens a per-conversation typing channel. The handle reads the OTHER
  /// party's typing state and lets you broadcast your own.
  ConversationTyping joinTyping({
    required String conversationId,
    required String myUserId,
  }) {
    final channel = _client.channel('typing:$conversationId');
    final controller = StreamController<bool>.broadcast();
    Timer? autoClear;

    void onEvent(Map<String, dynamic> payload, {required bool typing}) {
      if (payload['user_id'] == myUserId) return; // ignore our own echo
      autoClear?.cancel();
      if (!controller.isClosed) controller.add(typing);
      if (typing) {
        // Safety net: clear the indicator if the sender never sends "stop".
        autoClear = Timer(const Duration(seconds: 5), () {
          if (!controller.isClosed) controller.add(false);
        });
      }
    }

    channel
        .onBroadcast(
          event: 'typing',
          callback: (p, [_]) => onEvent(p, typing: true),
        )
        .onBroadcast(
          event: 'stop',
          callback: (p, [_]) => onEvent(p, typing: false),
        )
        .subscribe();

    return ConversationTyping(
      otherIsTyping: controller.stream,
      setTyping: (isTyping) {
        channel.sendBroadcastMessage(
          event: isTyping ? 'typing' : 'stop',
          payload: {'user_id': myUserId},
        );
      },
      dispose: () async {
        autoClear?.cancel();
        await controller.close();
        await _client.removeChannel(channel);
      },
    );
  }
}
