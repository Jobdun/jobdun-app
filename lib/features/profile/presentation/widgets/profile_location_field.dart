import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';

import '../../../../core/config/env.dart';
import '../../../../core/design/widgets/field_label.dart';
import '../../../../core/services/places_service.dart';
import '../../../../core/widgets/inputs/j_place_field.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
import '../../domain/entities/builder_profile.dart';
import '../../domain/entities/trade_profile.dart';

/// Builds the JPlaceResult prefill from existing profile fields when the row
/// already has the post-MapTiler 4-tuple (place_id + lat + lng + formatted
/// address). Returns null on legacy rows — those re-prompt the user to pick
/// rather than silently rendering a partially-populated input.
JPlaceResult? buildProfilePlaceInitial({
  required bool isBuilder,
  BuilderProfile? builderProfile,
  TradeProfile? tradeProfile,
}) {
  final placeId = isBuilder
      ? builderProfile?.servicePlaceId
      : tradeProfile?.basePlaceId;
  final lat = isBuilder
      ? builderProfile?.serviceLatitude
      : tradeProfile?.baseLatitude;
  final lng = isBuilder
      ? builderProfile?.serviceLongitude
      : tradeProfile?.baseLongitude;
  final formatted = isBuilder
      ? builderProfile?.serviceFormattedAddress
      : tradeProfile?.baseFormattedAddress;
  final suburb = isBuilder
      ? builderProfile?.serviceSuburb
      : tradeProfile?.baseSuburb;
  final state = isBuilder
      ? builderProfile?.serviceState
      : tradeProfile?.baseState;
  final postcode = isBuilder
      ? builderProfile?.servicePostcode
      : tradeProfile?.basePostcode;
  if (placeId == null ||
      lat == null ||
      lng == null ||
      formatted == null ||
      suburb == null ||
      state == null ||
      postcode == null) {
    return null;
  }
  return JPlaceResult(
    placeId: placeId,
    formattedAddress: formatted,
    suburb: suburb,
    state: state,
    postcode: postcode,
    latitude: lat,
    longitude: lng,
    mainText: suburb,
    secondaryText: '$state $postcode, Australia',
  );
}

/// Activates the MapTiler-backed [JPlaceField] when a MapTiler key is wired
/// (`.env` or `--dart-define`); falls back to the legacy 3-field input
/// otherwise. Both branches stay in source until the post-launch soak (Phase
/// 6 of the location-picker initiative) — at which point the legacy branch
/// is deleted.
///
/// Activation path:
///   1. Add `MAPTILER_API_KEY=...` to .env (or pass via --dart-define).
///   2. `flutter run` — JPlaceField takes over automatically.
///
/// Override knobs:
///   `--dart-define=PLACES_ENABLED=true`   forces the picker on (e.g. tests
///                                         where the key is stubbed via a
///                                         provider override).
///   `--dart-define=PLACES_ENABLED=false`  forces the legacy 3-field input
///                                         on (useful if the picker
///                                         misbehaves in production and we
///                                         need to hot-fix without a code
///                                         change).
bool get kPlacesEnabled {
  const override = String.fromEnvironment('PLACES_ENABLED');
  if (override == 'true') return true;
  if (override == 'false') return false;
  return AppEnv.hasMaptilerApiKey;
}

/// One widget rendered into both the trade and builder profile-edit forms in
/// place of the legacy SUBURB / STATE / POSTCODE row.
///
/// When [kPlacesEnabled] is true (Phase 3+ of the location-picker initiative)
/// renders [JPlaceField] backed by `placesServiceProvider`. Parent reads
/// `values['place']` as a [JPlaceResult] and splits it into the trade /
/// builder profile model.
///
/// When false (today's default) renders the legacy 3-field input that the
/// page used pre-MapTiler. Parent keeps reading `values['suburb']`,
/// `values['state']`, `values['postcode']` exactly as it did before.
class ProfileLocationField extends StatelessWidget {
  const ProfileLocationField({
    super.key,
    required this.label,
    required this.legacyInitial,
    required this.placeInitial,
  });

  /// Uppercase Oswald label rendered above the field. Trade=`BASE LOCATION`,
  /// builder=`SERVICE LOCATION`.
  final String label;

  /// Suburb / state / postcode preload from the existing profile row. Used
  /// only in the legacy 3-field branch — the MapTiler branch derives initial
  /// state from [placeInitial].
  final ({String? suburb, String? state, String? postcode}) legacyInitial;

  /// Pre-built [JPlaceResult] when the profile already has `place_id` +
  /// lat/lng + formatted_address. Null on legacy rows — those re-prompt the
  /// user to pick on next edit, no silent overwrite.
  final JPlaceResult? placeInitial;

  @override
  Widget build(BuildContext context) {
    return kPlacesEnabled
        ? _PlaceBranch(label: label, initialValue: placeInitial)
        : _LegacyBranch(label: label, initial: legacyInitial);
  }
}

class _PlaceBranch extends StatelessWidget {
  const _PlaceBranch({required this.label, required this.initialValue});

  final String label;
  final JPlaceResult? initialValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        Gap(8.h),
        JPlaceField(
          name: 'place',
          label: label,
          initialValue: initialValue,
          validator: (value) =>
              value == null ? 'Pick a suburb to continue.' : null,
        ),
      ],
    );
  }
}

class _LegacyBranch extends StatelessWidget {
  const _LegacyBranch({required this.label, required this.initial});

  final String label;
  final ({String? suburb, String? state, String? postcode}) initial;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        Gap(8.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: JTextField(
                name: 'suburb',
                hint: 'Suburb',
                initialValue: initial.suburb,
                validator: FormBuilderValidators.required(
                  errorText: 'Suburb is required.',
                ),
              ),
            ),
            Gap(10.w),
            Expanded(
              flex: 2,
              child: JTextField(
                name: 'state',
                hint: 'State',
                initialValue: initial.state,
              ),
            ),
            Gap(10.w),
            Expanded(
              flex: 3,
              child: JTextField(
                name: 'postcode',
                hint: 'Postcode',
                initialValue: initial.postcode,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: FormBuilderValidators.match(
                  RegExp(r'^\d{3,4}$'),
                  errorText: 'AU postcode (3 or 4 digits).',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

