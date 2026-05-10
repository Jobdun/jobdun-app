import '../../domain/entities/job.dart';

class JobModel extends Job {
  const JobModel({
    required super.id,
    required super.builderId,
    required super.title,
    required super.description,
    required super.tradeTypeRequired,
    required super.suburb,
    required super.state,
    required super.postcode,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    super.budgetMin,
    super.budgetMax,
    super.budgetType,
    super.urgency,
    super.startDate,
    super.estimatedDurationDays,
    super.durationText,
    super.requiresWhiteCard,
    super.requiresPublicLiability,
    super.requiresVerified,
    super.requiredCertifications,
    super.applicationCount,
    super.viewCount,
    super.publishedAt,
    super.hiredTradeId,
    super.deletedAt,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) => JobModel(
    id: json['id'] as String,
    builderId: json['builder_id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    tradeTypeRequired: json['trade_type_required'] as String? ?? '',
    suburb: json['suburb'] as String? ?? '',
    state: json['state'] as String? ?? '',
    postcode: json['postcode'] as String? ?? '',
    status: JobStatusX.fromDb(json['status'] as String? ?? 'open'),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    budgetMin: (json['budget_min'] as num?)?.toDouble(),
    budgetMax: (json['budget_max'] as num?)?.toDouble(),
    budgetType: json['budget_type'] != null
        ? BudgetTypeX.fromDb(json['budget_type'] as String)
        : null,
    urgency: json['urgency'] != null
        ? JobUrgencyX.fromDb(json['urgency'] as String)
        : JobUrgency.standard,
    startDate: json['start_date'] != null
        ? DateTime.parse(json['start_date'] as String)
        : null,
    estimatedDurationDays: json['estimated_duration_days'] as int?,
    durationText: json['duration_text'] as String?,
    requiresWhiteCard: json['requires_white_card'] as bool? ?? false,
    requiresPublicLiability: json['requires_public_liability'] as bool? ?? true,
    requiresVerified: json['requires_verified'] as bool? ?? true,
    requiredCertifications:
        (json['required_certifications'] as List<dynamic>?)?.cast<String>() ?? [],
    applicationCount: json['application_count'] as int? ?? 0,
    viewCount: json['view_count'] as int? ?? 0,
    publishedAt: json['published_at'] != null
        ? DateTime.parse(json['published_at'] as String)
        : null,
    hiredTradeId: json['hired_trade_id'] as String?,
    deletedAt: json['deleted_at'] != null
        ? DateTime.parse(json['deleted_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'builder_id': builderId,
    'title': title,
    'description': description,
    'trade_type_required': tradeTypeRequired,
    'suburb': suburb,
    'state': state,
    'postcode': postcode,
    'status': status.dbValue,
    'budget_min': budgetMin,
    'budget_max': budgetMax,
    'budget_type': budgetType?.dbValue,
    'urgency': urgency.dbValue,
    'start_date': startDate?.toIso8601String().split('T').first,
    'estimated_duration_days': estimatedDurationDays,
    'duration_text': durationText,
    'requires_white_card': requiresWhiteCard,
    'requires_public_liability': requiresPublicLiability,
    'requires_verified': requiresVerified,
    'required_certifications': requiredCertifications,
  };
}
