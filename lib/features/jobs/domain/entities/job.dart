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

  /// "Active" = live work the builder is managing: open (taking applicants)
  /// or filled (assigned / in progress). Excludes draft, closed, cancelled.
  bool get isActive => this == JobStatus.open || this == JobStatus.filled;

  static JobStatus fromDb(String value) => JobStatus.values.firstWhere(
    (s) => s.dbValue == value,
    orElse: () => JobStatus.open,
  );
}

// Matches schema enum urgency
enum JobUrgency { standard, urgent }

extension JobUrgencyX on JobUrgency {
  String get dbValue => name;
  static JobUrgency fromDb(String v) => JobUrgency.values.firstWhere(
    (u) => u.dbValue == v,
    orElse: () => JobUrgency.standard,
  );
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
  static BudgetType fromDb(String v) => BudgetType.values.firstWhere(
    (b) => b.dbValue == v,
    orElse: () => BudgetType.fixed,
  );
}

// Matches schema enum job_pricing_unit: hourly|sqm|lm|per_job. The unit a job's
// price (and any tradie quote against it) is expressed in. Always set.
enum PricingUnit { hourly, sqm, lm, perJob }

extension PricingUnitX on PricingUnit {
  String get dbValue => switch (this) {
    PricingUnit.perJob => 'per_job',
    _ => name,
  };

  /// Full selector label (AU spelling — "metre", "m²").
  String get label => switch (this) {
    PricingUnit.hourly => 'Per hour',
    PricingUnit.sqm => 'Per m²',
    PricingUnit.lm => 'Per lineal metre',
    PricingUnit.perJob => 'Per job',
  };

  /// Compact suffix after an amount, e.g. "\$85/hr". Per-job carries no suffix.
  String get suffix => switch (this) {
    PricingUnit.hourly => '/hr',
    PricingUnit.sqm => '/m²',
    PricingUnit.lm => '/lm',
    PricingUnit.perJob => '',
  };

  static PricingUnit fromDb(String v) => switch (v) {
    'per_job' => PricingUnit.perJob,
    'sqm' => PricingUnit.sqm,
    'lm' => PricingUnit.lm,
    _ => PricingUnit.hourly,
  };
}

// Matches schema enum job_pricing_type: builder_set|request_quote. Whether the
// builder named a price or is asking tradies to quote. Always set.
enum PricingType { builderSet, requestQuote }

extension PricingTypeX on PricingType {
  String get dbValue => switch (this) {
    PricingType.builderSet => 'builder_set',
    PricingType.requestQuote => 'request_quote',
  };

  String get label => switch (this) {
    PricingType.builderSet => 'Set price',
    PricingType.requestQuote => 'Request quotes',
  };

  static PricingType fromDb(String v) =>
      v == 'request_quote' ? PricingType.requestQuote : PricingType.builderSet;
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
    this.pricingUnit = PricingUnit.perJob,
    this.pricingType = PricingType.builderSet,
    this.budgetAmount,
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
    this.latitude,
    this.longitude,
    this.formattedAddress,
    this.placeId,
  });

  final String id;
  final String builderId;
  final String title;
  final String description;
  final String tradeTypeRequired;
  final String suburb;
  final String state;
  final String postcode;
  // Legacy budget fields — kept for backward compatibility (the create path now
  // writes pricingUnit/pricingType/budgetAmount). Not emitted by JobModel.toJson.
  final double? budgetMin;
  final double? budgetMax;
  final BudgetType? budgetType;
  // Pricing model (negotiation anchor — Jobdun never touches money).
  final PricingUnit pricingUnit;
  final PricingType pricingType;
  final double? budgetAmount;
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
  final double? latitude;
  final double? longitude;
  // Set by JPlaceField on job-create when the user picks a MapTiler suggestion.
  // Backward-compatible: legacy rows have these as null and continue to render
  // via `suburb`/`state`/`postcode` alone.
  final String? formattedAddress;
  final String? placeId;

  String get displayBudget {
    if (pricingType == PricingType.requestQuote) return 'Quotes requested';
    if (budgetAmount == null) return 'Negotiable';
    return '\$${budgetAmount!.toStringAsFixed(0)}${pricingUnit.suffix}';
  }

  String get displayLocation => '$suburb, $state';

  bool get hasLocation => latitude != null && longitude != null;

  @override
  List<Object?> get props => [id, builderId, title, status, tradeTypeRequired];
}
