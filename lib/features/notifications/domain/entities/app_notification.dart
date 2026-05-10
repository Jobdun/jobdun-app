import 'package:equatable/equatable.dart';

// Matches schema enum notification_type exactly
enum NotificationType {
  applicationReceived,
  applicationStatusChanged,
  newMessage,
  hireConfirmed,
  hireDeclined,
  verificationApproved,
  verificationRejected,
  documentExpiring,
  documentExpired,
  reviewReceived,
  jobFilled,
  systemAnnouncement,
}

extension NotificationTypeX on NotificationType {
  String get dbValue => switch (this) {
    NotificationType.applicationReceived => 'application_received',
    NotificationType.applicationStatusChanged => 'application_status_changed',
    NotificationType.newMessage => 'new_message',
    NotificationType.hireConfirmed => 'hire_confirmed',
    NotificationType.hireDeclined => 'hire_declined',
    NotificationType.verificationApproved => 'verification_approved',
    NotificationType.verificationRejected => 'verification_rejected',
    NotificationType.documentExpiring => 'document_expiring',
    NotificationType.documentExpired => 'document_expired',
    NotificationType.reviewReceived => 'review_received',
    NotificationType.jobFilled => 'job_filled',
    NotificationType.systemAnnouncement => 'system_announcement',
  };

  static NotificationType fromDb(String v) {
    const map = {
      'application_received': NotificationType.applicationReceived,
      'application_status_changed': NotificationType.applicationStatusChanged,
      'new_message': NotificationType.newMessage,
      'hire_confirmed': NotificationType.hireConfirmed,
      'hire_declined': NotificationType.hireDeclined,
      'verification_approved': NotificationType.verificationApproved,
      'verification_rejected': NotificationType.verificationRejected,
      'document_expiring': NotificationType.documentExpiring,
      'document_expired': NotificationType.documentExpired,
      'review_received': NotificationType.reviewReceived,
      'job_filled': NotificationType.jobFilled,
      'system_announcement': NotificationType.systemAnnouncement,
    };
    return map[v] ?? NotificationType.systemAnnouncement;
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
  final NotificationType type;
  final String title;
  final String body;
  final DateTime? readAt;   // null = unread; matches schema read_at column
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  @override
  List<Object?> get props => [id, userId, type, createdAt];
}
