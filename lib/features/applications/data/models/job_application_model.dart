import '../../domain/entities/job_application.dart';

class JobApplicationModel extends JobApplication {
  const JobApplicationModel({
    required super.id,
    required super.jobId,
    required super.tradeId,
    required super.builderId,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    super.coverNote,
    super.proposedRate,
    super.proposedRateType,
    super.quoteAmount,
    super.availableFrom,
    super.rejectionReason,
    super.jobTitle,
    super.jobSuburb,
    super.jobState,
    super.jobStatus,
    super.jobBudgetAmount,
    super.jobPricingUnit,
    super.jobPricingType,
    super.tradeFullName,
    super.tradePrimaryTrade,
    super.tradeIsVerified,
    super.tradeAvatarUrl,
    super.builderCompanyName,
  });

  factory JobApplicationModel.fromJson(Map<String, dynamic> json) {
    final status = ApplicationStatusX.fromDb(
      json['status'] as String? ?? 'pending',
    );

    // Support flat row or nested joins
    final jobData = json['jobs'] as Map<String, dynamic>?;
    final tradeData = json['trade_profiles'] as Map<String, dynamic>?;
    final builderData = json['builder_profiles'] as Map<String, dynamic>?;
    // avatar_url lives on `profiles` (merged separately) — not trade_profiles.
    final profileData = json['profiles'] as Map<String, dynamic>?;

    return JobApplicationModel(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      tradeId: json['trade_id'] as String,
      builderId: json['builder_id'] as String,
      status: status,
      coverNote: json['cover_note'] as String?,
      proposedRate: (json['proposed_rate'] as num?)?.toDouble(),
      proposedRateType: json['proposed_rate_type'] as String?,
      quoteAmount: (json['quote_amount'] as num?)?.toDouble(),
      availableFrom: json['available_from'] != null
          ? DateTime.parse(json['available_from'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      // Joined job fields
      jobTitle: jobData?['title'] as String?,
      jobSuburb: jobData?['suburb'] as String?,
      jobState: jobData?['state'] as String?,
      jobStatus: jobData?['status'] as String?,
      jobBudgetAmount: (jobData?['budget_amount'] as num?)?.toDouble(),
      jobPricingUnit: jobData?['pricing_unit'] as String?,
      jobPricingType: jobData?['pricing_type'] as String?,
      // Joined trade profile fields
      tradeFullName: tradeData?['full_name'] as String?,
      tradePrimaryTrade: tradeData?['primary_trade'] as String?,
      tradeIsVerified: tradeData?['is_verified'] as bool?,
      tradeAvatarUrl: profileData?['avatar_url'] as String?,
      // Joined builder profile fields
      builderCompanyName: builderData?['company_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    'trade_id': tradeId,
    'builder_id': builderId,
    'cover_note': coverNote,
    'proposed_rate': proposedRate,
    'proposed_rate_type': proposedRateType,
    'quote_amount': quoteAmount,
    'available_from': availableFrom?.toIso8601String().split('T').first,
  };
}
