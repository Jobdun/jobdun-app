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
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime? readAt; // null = unread
  final DateTime? deletedAt; // null = not deleted
  final DateTime? editedAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;
  bool get isDeleted => deletedAt != null;

  @override
  List<Object?> get props => [id, conversationId, senderId, createdAt];
}
