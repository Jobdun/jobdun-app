import 'dart:async';

/// Handle for one conversation's realtime typing channel. Returned by the data
/// layer, consumed by the thread page — a domain type so presentation never
/// imports the realtime service directly.
class ConversationTyping {
  const ConversationTyping({
    required this.otherIsTyping,
    required this.setTyping,
    required this.dispose,
  });

  /// Emits true/false as the OTHER participant starts/stops typing.
  final Stream<bool> otherIsTyping;

  /// Broadcast our own typing state to the other participant.
  final void Function(bool isTyping) setTyping;

  /// Tear down the channel + stream.
  final Future<void> Function() dispose;
}
