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
    this.attachmentPath,
    this.attachmentMime,
    this.attachmentW,
    this.attachmentH,
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
  // Storage path in the `chat-attachments` bucket + its mime/dimensions.
  // Null for plain text messages.
  final String? attachmentPath;
  final String? attachmentMime;
  final int? attachmentW;
  final int? attachmentH;

  bool get isRead => readAt != null;
  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null;
  bool get hasImage =>
      attachmentPath != null && (attachmentMime?.startsWith('image/') ?? false);

  Message copyWith({
    String? body,
    DateTime? readAt,
    DateTime? deletedAt,
    DateTime? editedAt,
  }) => Message(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    body: body ?? this.body,
    createdAt: createdAt,
    readAt: readAt ?? this.readAt,
    deletedAt: deletedAt ?? this.deletedAt,
    editedAt: editedAt ?? this.editedAt,
    clientTag: clientTag,
    attachmentPath: attachmentPath,
    attachmentMime: attachmentMime,
    attachmentW: attachmentW,
    attachmentH: attachmentH,
  );

  @override
  List<Object?> get props => [
    id,
    conversationId,
    senderId,
    createdAt,
    body,
    deletedAt,
    editedAt,
    attachmentPath,
  ];
}
