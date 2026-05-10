import '../../domain/entities/app_notification.dart';

class NotificationModel extends AppNotification {
  const NotificationModel({
    required super.id,
    required super.userId,
    required super.type,
    required super.title,
    required super.body,
    required super.createdAt,
    super.readAt,
    super.data,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) => NotificationModel(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    type: NotificationTypeX.fromDb(json['type'] as String? ?? 'system_announcement'),
    title: json['title'] as String,
    body: json['body'] as String,
    readAt: json['read_at'] != null
        ? DateTime.parse(json['read_at'] as String)
        : null,
    data: json['data'] as Map<String, dynamic>?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
