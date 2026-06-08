import '../../domain/entities/message.dart';

class MessageModel extends Message {
  const MessageModel({
    required super.id,
    required super.conversationId,
    required super.senderId,
    required super.body,
    required super.createdAt,
    super.readAt,
    super.deletedAt,
    super.editedAt,
    super.clientTag,
    super.attachmentPath,
    super.attachmentMime,
    super.attachmentW,
    super.attachmentH,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
    id: json['id'] as String,
    conversationId: json['conversation_id'] as String,
    senderId: json['sender_id'] as String,
    body: json['body'] as String,
    clientTag: json['client_tag'] as String?,
    attachmentPath: json['attachment_path'] as String?,
    attachmentMime: json['attachment_mime'] as String?,
    attachmentW: json['attachment_w'] as int?,
    attachmentH: json['attachment_h'] as int?,
    readAt: json['read_at'] != null
        ? DateTime.parse(json['read_at'] as String)
        : null,
    deletedAt: json['deleted_at'] != null
        ? DateTime.parse(json['deleted_at'] as String)
        : null,
    editedAt: json['edited_at'] != null
        ? DateTime.parse(json['edited_at'] as String)
        : null,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'conversation_id': conversationId,
    'sender_id': senderId,
    'body': body,
    if (clientTag != null) 'client_tag': clientTag,
  };
}
