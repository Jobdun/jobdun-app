import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/services/places_service.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../domain/entities/profile_patches.dart';
import '../../providers/profile_provider.dart';
import '../profile_location_field.dart';
import 'edit_sheet_scaffold.dart';

/// Quick-edit sheet for the base / service location. Patches only the
/// location columns of the role table. The four geocode extras (formatted
/// address, place id, lat, lng) are written ONLY when the user picked via the
/// place field — a legacy 3-field edit must not wipe stored coordinates.
class LocationSheet extends ConsumerStatefulWidget {
  const LocationSheet({super.key});

  @override
  ConsumerState<LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends ConsumerState<LocationSheet> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _dirty = false;
  bool _saving = false;
  String? _error;

  String? _nullIfBlank(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();

  Future<void> _save() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;
    final isBuilder =
        ref.read(authControllerProvider.select((s) => s.role)) ==
        UserRole.builder;

    final pickedPlace = values['place'] as JPlaceResult?;
    final suburb = pickedPlace?.suburb ?? (values['suburb'] as String?) ?? '';
    final auState = pickedPlace?.state ?? values['state'] as String?;
    final postcode = pickedPlace?.postcode ?? values['postcode'] as String?;

    Option<String?> placeText(String? v) =>
        pickedPlace == null ? const None() : Some(_nullIfBlank(v));
    Option<double?> placeNum(double? v) =>
        pickedPlace == null ? const None() : Some(v);

    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .savePatches(
          trade: isBuilder
              ? null
              : TradeProfilePatch(
                  baseSuburb: Some(_nullIfBlank(suburb)),
                  baseState: Some(_nullIfBlank(auState)),
                  basePostcode: Some(_nullIfBlank(postcode)),
                  baseFormattedAddress: placeText(
                    pickedPlace?.formattedAddress,
                  ),
                  basePlaceId: placeText(pickedPlace?.placeId),
                  baseLatitude: placeNum(pickedPlace?.latitude),
                  baseLongitude: placeNum(pickedPlace?.longitude),
                ),
          builder: isBuilder
              ? BuilderProfilePatch(
                  serviceSuburb: Some(_nullIfBlank(suburb)),
                  serviceState: Some(_nullIfBlank(auState)),
                  servicePostcode: Some(_nullIfBlank(postcode)),
                  serviceFormattedAddress: placeText(
                    pickedPlace?.formattedAddress,
                  ),
                  servicePlaceId: placeText(pickedPlace?.placeId),
                  serviceLatitude: placeNum(pickedPlace?.latitude),
                  serviceLongitude: placeNum(pickedPlace?.longitude),
                )
              : null,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error =
            ref.read(profileControllerProvider).error ??
            "Couldn't save. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.read(profileControllerProvider);
    final bp = state.builderProfile;
    final tp = state.tradeProfile;
    final isBuilder =
        ref.watch(authControllerProvider.select((s) => s.role)) ==
        UserRole.builder;

    // One title only — the sheet header names the field, so the inner widget
    // renders no label of its own (it used to stack the same words 3×).
    return EditSheetScaffold(
      title: isBuilder ? 'Service location' : 'Base location',
      isDirty: _dirty,
      isSaving: _saving,
      error: _error,
      onSave: _save,
      body: FormBuilder(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: () {
          if (!_dirty) setState(() => _dirty = true);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileLocationField(
              legacyInitial: (
                suburb: isBuilder ? bp?.serviceSuburb : tp?.baseSuburb,
                state: isBuilder ? bp?.serviceState : tp?.baseState,
                postcode: isBuilder ? bp?.servicePostcode : tp?.basePostcode,
              ),
              placeInitial: buildProfilePlaceInitial(
                isBuilder: isBuilder,
                builderProfile: bp,
                tradeProfile: tp,
              ),
            ),
            Gap(AppSpacing.sm.h),
          ],
        ),
      ),
    );
  }
}
