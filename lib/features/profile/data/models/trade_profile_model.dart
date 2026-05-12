import '../../domain/entities/trade_profile.dart';

class TradeProfileModel extends TradeProfile {
  const TradeProfileModel({
    required super.id,
    required super.fullName,
    required super.primaryTrade,
    super.crewSize,
    super.yearsExperience,
    super.hourlyRateMin,
    super.hourlyRateMax,
    super.hourlyRateVisible,
    super.serviceRadiusKm,
    super.baseSuburb,
    super.baseState,
    super.basePostcode,
    super.about,
    super.isVerified,
    super.verifiedAt,
    super.totalApplications,
    super.hireCount,
    super.jobsCompleted,
    super.averageRating,
    super.ratingCount,
  });

  factory TradeProfileModel.fromJson(Map<String, dynamic> json) =>
      TradeProfileModel(
        id: json['id'] as String,
        fullName: json['full_name'] as String? ?? '',
        primaryTrade: json['primary_trade'] as String? ?? '',
        crewSize: json['crew_size'] as int? ?? 1,
        yearsExperience: json['years_experience'] as int?,
        hourlyRateMin: (json['hourly_rate_min'] as num?)?.toDouble(),
        hourlyRateMax: (json['hourly_rate_max'] as num?)?.toDouble(),
        hourlyRateVisible: json['hourly_rate_visible'] as bool? ?? true,
        serviceRadiusKm: json['service_radius_km'] as int? ?? 50,
        baseSuburb: json['base_suburb'] as String?,
        baseState: json['base_state'] as String?,
        basePostcode: json['base_postcode'] as String?,
        about: json['about'] as String?,
        isVerified: json['is_verified'] as bool? ?? false,
        verifiedAt: json['verified_at'] != null
            ? DateTime.parse(json['verified_at'] as String)
            : null,
        totalApplications: json['total_applications'] as int? ?? 0,
        hireCount: json['hire_count'] as int? ?? 0,
        jobsCompleted: json['jobs_completed'] as int? ?? 0,
        averageRating: (json['average_rating'] as num?)?.toDouble(),
        ratingCount: json['rating_count'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'primary_trade': primaryTrade,
    'crew_size': crewSize,
    'years_experience': yearsExperience,
    'hourly_rate_min': hourlyRateMin,
    'hourly_rate_max': hourlyRateMax,
    'hourly_rate_visible': hourlyRateVisible,
    'service_radius_km': serviceRadiusKm,
    'base_suburb': baseSuburb,
    'base_state': baseState,
    'base_postcode': basePostcode,
    'about': about,
  };
}
