import 'package:fpdart/fpdart.dart';

/// Partial-update payloads for the three profile tables. Semantics:
/// `None` = leave the column untouched (absent from the write payload),
/// `Some(v)` = write v, `Some(null)` = clear a nullable column.
///
/// This is the fix for the null-wipe hazard: the legacy full-row save
/// (`update(profile.toJson())`) nulled every column it wasn't handed.
class UserProfilePatch {
  const UserProfilePatch({this.displayName = const None()});

  final Option<String> displayName;

  bool get isEmpty => displayName.isNone();
}

class TradeProfilePatch {
  const TradeProfilePatch({
    this.fullName = const None(),
    this.primaryTrade = const None(),
    this.tradeOther = const None(),
    this.yearsExperience = const None(),
    this.hourlyRateMin = const None(),
    this.hourlyRateMax = const None(),
    this.hourlyRateVisible = const None(),
    this.isAvailable = const None(),
    this.availableFrom = const None(),
    this.baseSuburb = const None(),
    this.baseState = const None(),
    this.basePostcode = const None(),
    this.baseFormattedAddress = const None(),
    this.basePlaceId = const None(),
    this.baseLatitude = const None(),
    this.baseLongitude = const None(),
    this.about = const None(),
  });

  final Option<String> fullName;
  final Option<String> primaryTrade;
  final Option<String?> tradeOther;
  final Option<int?> yearsExperience;
  final Option<double?> hourlyRateMin;
  final Option<double?> hourlyRateMax;
  final Option<bool> hourlyRateVisible;
  final Option<bool> isAvailable;
  final Option<DateTime?> availableFrom;
  final Option<String?> baseSuburb;
  final Option<String?> baseState;
  final Option<String?> basePostcode;
  final Option<String?> baseFormattedAddress;
  final Option<String?> basePlaceId;
  final Option<double?> baseLatitude;
  final Option<double?> baseLongitude;
  final Option<String?> about;

  bool get isEmpty =>
      fullName.isNone() &&
      primaryTrade.isNone() &&
      tradeOther.isNone() &&
      yearsExperience.isNone() &&
      hourlyRateMin.isNone() &&
      hourlyRateMax.isNone() &&
      hourlyRateVisible.isNone() &&
      isAvailable.isNone() &&
      availableFrom.isNone() &&
      baseSuburb.isNone() &&
      baseState.isNone() &&
      basePostcode.isNone() &&
      baseFormattedAddress.isNone() &&
      basePlaceId.isNone() &&
      baseLatitude.isNone() &&
      baseLongitude.isNone() &&
      about.isNone();
}

class BuilderProfilePatch {
  const BuilderProfilePatch({
    this.companyName = const None(),
    this.abn = const None(),
    this.contactName = const None(),
    this.contactPhone = const None(),
    this.yearsInBusiness = const None(),
    this.website = const None(),
    this.serviceSuburb = const None(),
    this.serviceState = const None(),
    this.servicePostcode = const None(),
    this.serviceFormattedAddress = const None(),
    this.servicePlaceId = const None(),
    this.serviceLatitude = const None(),
    this.serviceLongitude = const None(),
    this.about = const None(),
  });

  final Option<String> companyName;
  final Option<String?> abn;
  final Option<String?> contactName;
  final Option<String?> contactPhone;
  final Option<int?> yearsInBusiness;
  final Option<String?> website;
  final Option<String?> serviceSuburb;
  final Option<String?> serviceState;
  final Option<String?> servicePostcode;
  final Option<String?> serviceFormattedAddress;
  final Option<String?> servicePlaceId;
  final Option<double?> serviceLatitude;
  final Option<double?> serviceLongitude;
  final Option<String?> about;

  bool get isEmpty =>
      companyName.isNone() &&
      abn.isNone() &&
      contactName.isNone() &&
      contactPhone.isNone() &&
      yearsInBusiness.isNone() &&
      website.isNone() &&
      serviceSuburb.isNone() &&
      serviceState.isNone() &&
      servicePostcode.isNone() &&
      serviceFormattedAddress.isNone() &&
      servicePlaceId.isNone() &&
      serviceLatitude.isNone() &&
      serviceLongitude.isNone() &&
      about.isNone();
}
