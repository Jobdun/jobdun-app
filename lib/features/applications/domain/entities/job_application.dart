import 'package:equatable/equatable.dart';

enum ApplicationStatus { pending, shortlisted, accepted, rejected, withdrawn }

extension ApplicationStatusX on ApplicationStatus {
  String get label => switch (this) {
    ApplicationStatus.pending => 'Pending',
    ApplicationStatus.shortlisted => 'Shortlisted',
    ApplicationStatus.accepted => 'Accepted',
    ApplicationStatus.rejected => 'Rejected',
    ApplicationStatus.withdrawn => 'Withdrawn',
  };
}

class JobApplication extends Equatable {
  const JobApplication({
    required this.id,
    required this.jobId,
    required this.tradeId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.coverMessage,
  });

  final String id;
  final String jobId;
  final String tradeId;
  final ApplicationStatus status;
  final String? coverMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [id, jobId, tradeId, status];
}
