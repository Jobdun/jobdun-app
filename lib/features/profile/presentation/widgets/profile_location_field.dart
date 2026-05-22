import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/field_label.dart';
import '../../../../core/services/places_service.dart';
import '../../../../core/widgets/inputs/j_place_field.dart';
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

/// PLACES_ENABLED is a compile-time gate that flips this widget between two
/// modes — both kept in source until the post-launch soak (Phase 6 of the
/// location-picker initiative). Default `false` keeps every dev build on
/// the legacy 3-field input while engineers wire MapTiler keys.
///
/// To opt in:  flutter run --dart-define=PLACES_ENABLED=true
const bool kPlacesEnabled =
    bool.fromEnvironment('PLACES_ENABLED', defaultValue: false);

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
    return kPlacesEnabled ? _PlaceBranch(label: label, initialValue: placeInitial)
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
              child: _LegacyField(
                name: 'suburb',
                hint: 'Suburb',
                initial: initial.suburb,
                validator: FormBuilderValidators.required(
                  errorText: 'Suburb is required.',
                ),
              ),
            ),
            Gap(10.w),
            Expanded(
              flex: 2,
              child: _LegacyField(
                name: 'state',
                hint: 'State',
                initial: initial.state,
              ),
            ),
            Gap(10.w),
            Expanded(
              flex: 3,
              child: _LegacyField(
                name: 'postcode',
                hint: 'Postcode',
                initial: initial.postcode,
                keyboardType: TextInputType.number,
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.match(
                    RegExp(r'^\d{3,4}$'),
                    errorText: 'AU postcode (3 or 4 digits).',
                  ),
                ]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegacyField extends StatelessWidget {
  const _LegacyField({
    required this.name,
    required this.hint,
    required this.initial,
    this.validator,
    this.keyboardType,
  });

  final String name;
  final String hint;
  final String? initial;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return FormBuilderTextField(
      name: name,
      initialValue: initial,
      keyboardType: keyboardType,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
      style: tt.bodyLarge!.copyWith(color: c.text1, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        helperText: ' ',
        helperMaxLines: 2,
        errorMaxLines: 2,
      ),
    );
  }
}
