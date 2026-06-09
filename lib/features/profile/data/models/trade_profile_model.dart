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
    super.baseFormattedAddress,
    super.basePlaceId,
    super.baseLatitude,
    super.baseLongitude,
    super.about,
    super.tradeOther,
    super.licenceUrl,
    super.portfolioUrls,
    super.isVerified,
    super.verifiedAt,
    super.totalApplications,
    super.hireCount,
    super.jobsCompleted,
    super.averageRating,
    super.ratingCount,
    super.isAvailable,
    super.availableFrom,
    super.unavailableDates,
    super.deletedAt,
  });

  /// Parses a Postgres `date[]` (list of 'yyyy-MM-dd' strings) into date-only
  /// DateTimes. Tolerates null / missing column (pre-migration rows).
  static List<DateTime> _parseDates(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => DateTime.parse(e.toString()))
        .map((d) => DateTime(d.year, d.month, d.day))
        .toList();
  }

  static List<String> _encodeDates(List<DateTime> dates) =>
      dates.map((d) => d.toIso8601String().substring(0, 10)).toList();

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
        baseFormattedAddress: json['base_formatted_address'] as String?,
        basePlaceId: json['base_place_id'] as String?,
        baseLatitude: (json['base_latitude'] as num?)?.toDouble(),
        baseLongitude: (json['base_longitude'] as num?)?.toDouble(),
        about: json['about'] as String?,
        tradeOther: json['trade_other'] as String?,
        licenceUrl: json['licence_url'] as String?,
        portfolioUrls:
            (json['portfolio_urls'] as List?)?.cast<String>() ?? const [],
        isVerified: json['is_verified'] as bool? ?? false,
        verifiedAt: json['verified_at'] != null
            ? DateTime.parse(json['verified_at'] as String)
            : null,
        totalApplications: json['total_applications'] as int? ?? 0,
        hireCount: json['hire_count'] as int? ?? 0,
        jobsCompleted: json['jobs_completed'] as int? ?? 0,
        averageRating: (json['average_rating'] as num?)?.toDouble(),
        ratingCount: json['rating_count'] as int? ?? 0,
        isAvailable: json['is_available'] as bool? ?? true,
        availableFrom: json['available_from'] != null
            ? DateTime.parse(json['available_from'] as String)
            : null,
        unavailableDates: _parseDates(json['unavailable_dates']),
        deletedAt: json['deleted_at'] != null
            ? DateTime.parse(json['deleted_at'] as String)
            : null,
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
    'trade_other': tradeOther,
    'is_available': isAvailable,
    if (availableFrom != null)
      'available_from': availableFrom!.toIso8601String().substring(0, 10),
    // Post-MapTiler additions — emit only when set so writes don't fail
    // pre-migration on environments that haven't applied
    // 20260522000001_places_columns.sql yet.
    if (baseFormattedAddress != null)
      'base_formatted_address': baseFormattedAddress,
    if (basePlaceId != null) 'base_place_id': basePlaceId,
    if (baseLatitude != null) 'base_latitude': baseLatitude,
    if (baseLongitude != null) 'base_longitude': baseLongitude,
  };

  /// Full round-trip serialization for the offline cache (Phase 2). Unlike
  /// [toJson] (a write projection that omits verification + stats), this emits
  /// every key [fromJson] reads so a cached profile rehydrates identically
  /// offline. All values JSON-encodable.
  Map<String, dynamic> toCacheMap() => {
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
    'base_formatted_address': baseFormattedAddress,
    'base_place_id': basePlaceId,
    'base_latitude': baseLatitude,
    'base_longitude': baseLongitude,
    'about': about,
    'trade_other': tradeOther,
    'licence_url': licenceUrl,
    'portfolio_urls': portfolioUrls,
    'is_verified': isVerified,
    'verified_at': verifiedAt?.toIso8601String(),
    'total_applications': totalApplications,
    'hire_count': hireCount,
    'jobs_completed': jobsCompleted,
    'average_rating': averageRating,
    'rating_count': ratingCount,
    'is_available': isAvailable,
    'available_from': availableFrom?.toIso8601String(),
    'unavailable_dates': _encodeDates(unavailableDates),
    'deleted_at': deletedAt?.toIso8601String(),
  };
}
