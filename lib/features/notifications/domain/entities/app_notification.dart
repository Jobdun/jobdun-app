import 'package:equatable/equatable.dart';

/// Presentation-facing grouping of the free-text `notifications.type` column.
/// The DB does NOT constrain `type` (it's `text`) and producers have grown
/// over time (`new_job`, `message_received`, `application_status`,
/// `quote_requested`, …), so the entity keeps the raw string and derives the
/// category by prefix — mirroring `public.notification_category()` in
/// supabase/migrations/20260609000006_notification_preferences.sql.
enum NotificationCategory {
  job,
  message,
  application,
  quote,
  verification,
  review,
  announcement,
  other;

  static NotificationCategory fromType(String type) {
    final t = type.toLowerCase();
    if (t == 'new_job' || t == 'job_filled') return job;
    if (t.startsWith('message') || t == 'new_message') return message;
    if (t.startsWith('application') ||
        t.startsWith('hire') ||
        t == 'shortlisted') {
      return application;
    }
    if (t.startsWith('quote')) return quote;
    if (t.contains('verif') || t.startsWith('document_')) return verification;
    if (t.startsWith('review')) return review;
    if (t.contains('announcement')) return announcement;
    return other;
  }
}

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.data,
  });

  final String id;
  final String userId;

  /// Raw `notifications.type` value (free text in the DB).
  final String type;
  final String title;
  final String body;
  final DateTime? readAt; // null = unread; matches schema read_at column
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  NotificationCategory get category => NotificationCategory.fromType(type);

  /// Same notification stamped read — used for optimistic mark-read updates.
  AppNotification asRead(DateTime at) => AppNotification(
    id: id,
    userId: userId,
    type: type,
    title: title,
    body: body,
    createdAt: createdAt,
    readAt: readAt ?? at,
    data: data,
  );

  @override
  List<Object?> get props => [id, userId, type, createdAt, readAt];
}
