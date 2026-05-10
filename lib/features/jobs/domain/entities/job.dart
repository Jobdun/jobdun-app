import 'package:equatable/equatable.dart';

// Matches schema enum job_status: draft|open|filled|closed|cancelled
enum JobStatus { draft, open, filled, closed, cancelled }

extension JobStatusX on JobStatus {
  String get label => switch (this) {
    JobStatus.draft => 'Draft',
    JobStatus.open => 'Open',
    JobStatus.filled => 'Filled',
    JobStatus.closed => 'Closed',
    JobStatus.cancelled => 'Cancelled',
  };

  String get dbValue => name;

  static JobStatus fromDb(String value) => JobStatus.values.firstWhere(
    (s) => s.dbValue == value,
    orElse: () => JobStatus.open,
  );
}

// Matches schema enum urgency
enum JobUrgency { standard, urgent }

extension JobUrgencyX on JobUrgency {
  String get dbValue => name;
  static JobUrgency fromDb(String v) =>
      JobUrgency.values.firstWhere((u) => u.dbValue == v, orElse: () => JobUrgency.standard);
}

// Matches schema enum budget_type
enum BudgetType { hourly, daily, fixed, negotiable }

extension BudgetTypeX on BudgetType {
  String get dbValue => name;
  String get label => switch (this) {
    BudgetType.hourly => '/hr',
    BudgetType.daily => '/day',
    BudgetType.fixed => 'flat',
    BudgetType.negotiable => 'neg.',
  };
  static BudgetType fromDb(String v) =>
      BudgetType.values.firstWhere((b) => b.dbValue == v, orElse: () => BudgetType.fixed);
}

class Job extends Equatable {
  const Job({
    required this.id,
    required this.builderId,
    required this.title,
    required this.description,
    required this.tradeTypeRequired,
    required this.suburb,
    required this.state,
    required this.postcode,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.budgetMin,
    this.budgetMax,
    this.budgetType,
    this.urgency = JobUrgency.standard,
    this.startDate,
    this.estimatedDurationDays,
    this.durationText,
    this.requiresWhiteCard = false,
    this.requiresPublicLiability = true,
    this.requiresVerified = true,
    this.requiredCertifications = const [],
    this.applicationCount = 0,
    this.viewCount = 0,
    this.publishedAt,
    this.hiredTradeId,
    this.deletedAt,
  });

  final String id;
  final String builderId;
  final String title;
  final String description;
  final String tradeTypeRequired;
  final String suburb;
  final String state;
  final String postcode;
  final double? budgetMin;
  final double? budgetMax;
  final BudgetType? budgetType;
  final JobUrgency urgency;
  final DateTime? startDate;
  final int? estimatedDurationDays;
  final String? durationText;
  final bool requiresWhiteCard;
  final bool requiresPublicLiability;
  final bool requiresVerified;
  final List<String> requiredCertifications;
  final int applicationCount;
  final int viewCount;
  final JobStatus status;
  final DateTime? publishedAt;
  final String? hiredTradeId;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayBudget {
    if (budgetMin == null && budgetMax == null) return 'Negotiable';
    final suffix = budgetType?.label ?? '';
    if (budgetMin != null && budgetMax != null) {
      return '\$${budgetMin!.toStringAsFixed(0)}–\$${budgetMax!.toStringAsFixed(0)}$suffix';
    }
    final amount = budgetMin ?? budgetMax!;
    return '\$${amount.toStringAsFixed(0)}$suffix';
  }

  String get displayLocation => '$suburb, $state';

  @override
  List<Object?> get props => [id, builderId, title, status, tradeTypeRequired];
}
