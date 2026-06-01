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
    super.latitude,
    super.longitude,
    super.formattedAddress,
    super.placeId,
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
        (json['required_certifications'] as List<dynamic>?)?.cast<String>() ??
        [],
    applicationCount: json['application_count'] as int? ?? 0,
    viewCount: json['view_count'] as int? ?? 0,
    publishedAt: json['published_at'] != null
        ? DateTime.parse(json['published_at'] as String)
        : null,
    hiredTradeId: json['hired_trade_id'] as String?,
    deletedAt: json['deleted_at'] != null
        ? DateTime.parse(json['deleted_at'] as String)
        : null,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    formattedAddress: json['formatted_address'] as String?,
    placeId: json['place_id'] as String?,
  );

  /// Wraps a domain [Job] so the data layer can serialise it. Lets the
  /// presentation layer hand the repo a plain domain entity (it must not
  /// import this model) — the repo upgrades it here before `toJson`.
  factory JobModel.fromEntity(Job job) => JobModel(
    id: job.id,
    builderId: job.builderId,
    title: job.title,
    description: job.description,
    tradeTypeRequired: job.tradeTypeRequired,
    suburb: job.suburb,
    state: job.state,
    postcode: job.postcode,
    status: job.status,
    createdAt: job.createdAt,
    updatedAt: job.updatedAt,
    budgetMin: job.budgetMin,
    budgetMax: job.budgetMax,
    budgetType: job.budgetType,
    urgency: job.urgency,
    startDate: job.startDate,
    estimatedDurationDays: job.estimatedDurationDays,
    durationText: job.durationText,
    requiresWhiteCard: job.requiresWhiteCard,
    requiresPublicLiability: job.requiresPublicLiability,
    requiresVerified: job.requiresVerified,
    requiredCertifications: job.requiredCertifications,
    applicationCount: job.applicationCount,
    viewCount: job.viewCount,
    publishedAt: job.publishedAt,
    hiredTradeId: job.hiredTradeId,
    deletedAt: job.deletedAt,
    latitude: job.latitude,
    longitude: job.longitude,
    formattedAddress: job.formattedAddress,
    placeId: job.placeId,
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
    // Lat/lng/place_id/formatted_address are post-MapTiler additions. Emit
    // only when set so writes don't fail pre-migration on environments that
    // haven't applied 20260522000001_places_columns.sql yet.
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (formattedAddress != null) 'formatted_address': formattedAddress,
    if (placeId != null) 'place_id': placeId,
  };
}
