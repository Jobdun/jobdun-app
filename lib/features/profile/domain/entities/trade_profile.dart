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
    this.isAvailable = true,
    this.availableFrom,
    this.unavailableDates = const [],
    this.deletedAt,
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
  // "Open for work" toggle, driven by the trade in profile-edit. Search treats
  // `isAvailable || availableFrom <= today` as available now.
  final bool isAvailable;
  // When isAvailable is false, the date the trade becomes free again.
  final DateTime? availableFrom;
  // Specific dates the trade has blocked off (booked / on leave), set via the
  // availability calendar (#13). Date-only; builders see these on the profile.
  final List<DateTime> unavailableDates;
  // Soft-delete timestamp. Repository default reads filter on
  // `deletedAt == null`; deleted rows stay around so references in
  // job_applications and reviews still resolve.
  final DateTime? deletedAt;

  bool get hasLicence => licenceUrl != null && licenceUrl!.isNotEmpty;
  int get portfolioCount => portfolioUrls.length;

  String get displayLocation => (baseSuburb != null && baseState != null)
      ? '$baseSuburb, $baseState'
      : baseSuburb ?? baseState ?? '';

  /// Human-readable trade name. `primary_trade` is a slug, so `floor_tiler`
  /// reads "Floor Tiler".
  ///
  /// When the tradie picked "Other" the slug carries no information — the
  /// trade they typed lives in [tradeOther]. Falling through to it is the only
  /// way that answer ever reaches a screen: the picker and the edit sheet both
  /// write `trade_other`, but every display path goes through here, so an
  /// "Other → Scaffolder" tradie was shown, and searched as, plain "Other".
  String get displayTrade {
    final other = tradeOther?.trim();
    if (primaryTrade == 'other' && other != null && other.isNotEmpty) {
      return other;
    }
    return primaryTrade
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  /// Every field, deliberately.
  ///
  /// This used to be `[id, fullName, primaryTrade]`, which made two profiles
  /// differing only in rate, suburb, bio or availability compare *equal* — so
  /// a `ref.watch(...select((s) => s.tradeProfile))` would sit on a stale
  /// object and a saved edit would never reach the screen. No read site
  /// selects the whole profile today, which is the only reason it never bit;
  /// the first one to do so would have inherited a silent bug.
  @override
  List<Object?> get props => [
    id,
    fullName,
    primaryTrade,
    crewSize,
    yearsExperience,
    hourlyRateMin,
    hourlyRateMax,
    hourlyRateVisible,
    serviceRadiusKm,
    baseSuburb,
    baseState,
    basePostcode,
    baseFormattedAddress,
    basePlaceId,
    baseLatitude,
    baseLongitude,
    about,
    tradeOther,
    licenceUrl,
    portfolioUrls,
    isVerified,
    verifiedAt,
    totalApplications,
    hireCount,
    jobsCompleted,
    averageRating,
    ratingCount,
    isAvailable,
    availableFrom,
    unavailableDates,
    deletedAt,
  ];
}
