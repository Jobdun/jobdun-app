import 'package:fpdart/fpdart.dart';

import '../../domain/entities/profile_patches.dart';

// Pure patch → Supabase column-map builders. Column names mirror the
// `toJson()` maps of the corresponding *_model.dart files. A column appears
// in the result ONLY when the patch field is Some — this is what makes
// section saves safe (test: profile_patch_mappers_test.dart).

void _put<T>(Map<String, dynamic> map, String column, Option<T> field) {
  field.match(() {}, (v) => map[column] = v);
}

Map<String, dynamic> userProfilePatchColumns(UserProfilePatch p) {
  final map = <String, dynamic>{};
  _put(map, 'display_name', p.displayName);
  return map;
}

Map<String, dynamic> tradeProfilePatchColumns(TradeProfilePatch p) {
  final map = <String, dynamic>{};
  _put(map, 'full_name', p.fullName);
  _put(map, 'primary_trade', p.primaryTrade);
  _put(map, 'trade_other', p.tradeOther);
  _put(map, 'years_experience', p.yearsExperience);
  _put(map, 'hourly_rate_min', p.hourlyRateMin);
  _put(map, 'hourly_rate_max', p.hourlyRateMax);
  _put(map, 'hourly_rate_visible', p.hourlyRateVisible);
  _put(map, 'is_available', p.isAvailable);
  p.availableFrom.match(
    () {},
    (v) => map['available_from'] = v?.toIso8601String(),
  );
  _put(map, 'base_suburb', p.baseSuburb);
  _put(map, 'base_state', p.baseState);
  _put(map, 'base_postcode', p.basePostcode);
  _put(map, 'base_formatted_address', p.baseFormattedAddress);
  _put(map, 'base_place_id', p.basePlaceId);
  _put(map, 'base_latitude', p.baseLatitude);
  _put(map, 'base_longitude', p.baseLongitude);
  _put(map, 'about', p.about);
  return map;
}

Map<String, dynamic> builderProfilePatchColumns(BuilderProfilePatch p) {
  final map = <String, dynamic>{};
  _put(map, 'company_name', p.companyName);
  _put(map, 'abn', p.abn);
  _put(map, 'contact_name', p.contactName);
  _put(map, 'contact_phone', p.contactPhone);
  _put(map, 'years_in_business', p.yearsInBusiness);
  _put(map, 'website', p.website);
  _put(map, 'service_suburb', p.serviceSuburb);
  _put(map, 'service_state', p.serviceState);
  _put(map, 'service_postcode', p.servicePostcode);
  _put(map, 'service_formatted_address', p.serviceFormattedAddress);
  _put(map, 'service_place_id', p.servicePlaceId);
  _put(map, 'service_latitude', p.serviceLatitude);
  _put(map, 'service_longitude', p.serviceLongitude);
  _put(map, 'about', p.about);
  return map;
}
