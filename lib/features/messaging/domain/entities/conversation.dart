import 'package:equatable/equatable.dart';

import 'message.dart';

// Derived from messages — no separate DB table.
class Conversation extends Equatable {
  const Conversation({
    required this.jobId,
    required this.otherUserId,
    required this.otherUserName,
    this.lastMessage,
    this.unreadCount = 0,
  });

  final String jobId;
  final String otherUserId;
  final String otherUserName;
  final Message? lastMessage;
  final int unreadCount;

  @override
  List<Object?> get props => [jobId, otherUserId];
}
