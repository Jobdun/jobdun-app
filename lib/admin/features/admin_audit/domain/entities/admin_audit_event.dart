import 'package:equatable/equatable.dart';

enum AdminAuditSource { verification, role }

class AdminAuditEvent extends Equatable {
  const AdminAuditEvent({
    required this.id,
    required this.occurredAt,
    required this.source,
    required this.eventType,
    this.actorId,
    this.targetUserId,
    this.payloadPreview,
  });

  final String id;
  final DateTime occurredAt;
  final AdminAuditSource source;
  final String eventType;
  final String? actorId;
  final String? targetUserId;
  final String? payloadPreview;

  @override
  List<Object?> get props => [
    id,
    occurredAt,
    source,
    eventType,
    actorId,
    targetUserId,
    payloadPreview,
  ];
}
