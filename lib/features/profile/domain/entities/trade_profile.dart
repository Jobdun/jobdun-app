import 'package:equatable/equatable.dart';

// Matches public.trade_profiles table
class TradeProfile extends Equatable {
  const TradeProfile({
    required this.id,
    required this.fullName,
    required this.primaryTrade,
    this.crewSize = 1,
    this.yearsExperience,
    this.hourlyRateMin,
    this.hourlyRateMax,
    this.hourlyRateVisible = true,
    this.serviceRadiusKm = 50,
    this.baseSuburb,
    this.baseState,
    this.basePostcode,
    this.baseFormattedAddress,
    this.basePlaceId,
    this.baseLatitude,
    this.baseLongitude,
    this.about,
    this.tradeOther,
    this.licenceUrl,
    this.portfolioUrls = const [],
    this.isVerified = false,
    this.verifiedAt,
    this.totalApplications = 0,
    this.hireCount = 0,
    this.jobsCompleted = 0,
    this.averageRating,
    this.ratingCount = 0,
  });

  final String id;
  final String fullName;
  final String primaryTrade;
  final int crewSize;
  final int? yearsExperience;
  final double? hourlyRateMin;
  final double? hourlyRateMax;
  final bool hourlyRateVisible;
  final int serviceRadiusKm;
  final String? baseSuburb;
  final String? baseState;
  final String? basePostcode;
  // Set by JPlaceField on profile-edit. Null on legacy rows where the user
  // still hand-typed suburb/state/postcode pre-MapTiler. The home map prefers
  // (baseLatitude, baseLongitude) when both are non-null.
  final String? baseFormattedAddress;
  final String? basePlaceId;
  final double? baseLatitude;
  final double? baseLongitude;
  final String? about;
  // Free-text trade name when primaryTrade == 'other'. Mirrors
  // trade_profiles.trade_other; null whenever primaryTrade is a known value.
  final String? tradeOther;
  // Trade-licence storage path (private-docs bucket). Drives the
  // licence_uploaded slot in profile_completeness — null/empty = no licence.
  final String? licenceUrl;
  // Portfolio image URLs (public-media bucket). Mirrors trade_profiles.portfolio_urls.
  final List<String> portfolioUrls;
  final bool isVerified;
  final DateTime? verifiedAt;
  final int totalApplications;
  final int hireCount;
  final int jobsCompleted;
  final double? averageRating;
  final int ratingCount;

  bool get hasLicence => licenceUrl != null && licenceUrl!.isNotEmpty;
  int get portfolioCount => portfolioUrls.length;

  String get displayLocation => (baseSuburb != null && baseState != null)
      ? '$baseSuburb, $baseState'
      : baseSuburb ?? baseState ?? '';

  String get displayTrade => primaryTrade
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  List<Object?> get props => [id, fullName, primaryTrade];
}
