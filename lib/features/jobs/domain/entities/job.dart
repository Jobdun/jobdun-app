import 'package:equatable/equatable.dart';

enum JobStatus { draft, open, inReview, assigned, inProgress, completed, cancelled }

extension JobStatusX on JobStatus {
  String get label => switch (this) {
    JobStatus.draft => 'Draft',
    JobStatus.open => 'Open',
    JobStatus.inReview => 'In Review',
    JobStatus.assigned => 'Assigned',
    JobStatus.inProgress => 'In Progress',
    JobStatus.completed => 'Completed',
    JobStatus.cancelled => 'Cancelled',
  };

  // Snake-case value stored in Supabase
  String get dbValue => switch (this) {
    JobStatus.draft => 'draft',
    JobStatus.open => 'open',
    JobStatus.inReview => 'in_review',
    JobStatus.assigned => 'assigned',
    JobStatus.inProgress => 'in_progress',
    JobStatus.completed => 'completed',
    JobStatus.cancelled => 'cancelled',
  };

  static JobStatus fromDb(String value) => JobStatus.values.firstWhere(
    (s) => s.dbValue == value,
    orElse: () => JobStatus.open,
  );
}

class Job extends Equatable {
  const Job({
    required this.id,
    required this.builderId,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.location,
    this.budget,
    this.budgetType = 'fixed',
    this.startDate,
    this.tradeCategory,
    this.requiredSkills = const [],
    this.requiredLicences = const [],
  });

  final String id;
  final String builderId;
  final String title;
  final String description;
  final String? location;
  final double? budget;
  final String budgetType;
  final DateTime? startDate;
  final String? tradeCategory;
  final List<String> requiredSkills;
  final List<String> requiredLicences;
  final JobStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [id, builderId, title, status];
}
