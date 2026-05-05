import '../../domain/entities/message.dart';

class MessageModel extends Message {
  const MessageModel({
    required super.id,
    required super.jobId,
    required super.senderId,
    required super.receiverId,
    required super.body,
    required super.createdAt,
    super.isRead,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
    id: json['id'] as String,
    jobId: json['job_id'] as String,
    senderId: json['sender_id'] as String,
    receiverId: json['receiver_id'] as String,
    body: json['message'] as String,
    isRead: json['is_read'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    'sender_id': senderId,
    'receiver_id': receiverId,
    'message': body,
    'is_read': isRead,
  };
}
