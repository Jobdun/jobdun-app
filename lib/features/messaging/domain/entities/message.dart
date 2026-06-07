import 'package:equatable/equatable.dart';

class Message extends Equatable {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.deletedAt,
    this.editedAt,
    this.clientTag,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime? readAt; // null = unread
  final DateTime? deletedAt; // null = not deleted
  final DateTime? editedAt;
  final DateTime createdAt;
  // Client-generated idempotency key, echoed back from the server. Lets an
  // optimistic local bubble be matched to its server row (dedup by client_tag,
  // not by server id). Null for rows inserted before Phase A / server-only.
  final String? clientTag;

  bool get isRead => readAt != null;
  bool get isDeleted => deletedAt != null;

  @override
  List<Object?> get props => [id, conversationId, senderId, createdAt];
}
