import 'package:equatable/equatable.dart';

enum NotificationType {
  newJob,
  newApplication,
  applicationAccepted,
  applicationRejected,
  newMessage,
  verificationApproved,
  verificationRejected,
  jobStatusChanged,
}

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.data,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final bool isRead;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, userId, type, createdAt];
}
