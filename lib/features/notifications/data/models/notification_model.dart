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

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        type: json['type'] as String? ?? '',
        title: json['title'] as String,
        body: json['body'] as String,
        readAt: json['read_at'] != null
            ? DateTime.parse(json['read_at'] as String).toLocal()
            : null,
        data: json['data'] as Map<String, dynamic>?,
        // 2026-08-18 audit: .toLocal() so date rendering shows the AU day.
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}
