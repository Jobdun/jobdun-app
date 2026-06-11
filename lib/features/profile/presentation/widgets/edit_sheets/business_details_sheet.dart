import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:fpdart/fpdart.dart' show None, Some;
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/design/widgets/field_label.dart';
import '../../../../../core/widgets/inputs/j_text_field.dart';
import '../../../domain/entities/builder_profile.dart';
import '../../../domain/entities/profile_patches.dart';
import '../../providers/profile_provider.dart';
import 'edit_sheet_scaffold.dart';

/// Quick-edit sheet for builder business details: contact name + phone,
/// verified-locked company name + ABN, years in business, website. Saves only
/// those columns via BuilderProfilePatch; ABR-verified fields are excluded
/// from the patch entirely while locked.
class BusinessDetailsSheet extends ConsumerStatefulWidget {
  const BusinessDetailsSheet({super.key});

  @override
  ConsumerState<BusinessDetailsSheet> createState() =>
      _BusinessDetailsSheetState();
}

class _BusinessDetailsSheetState extends ConsumerState<BusinessDetailsSheet> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _dirty = false;
  bool _saving = false;
  String? _error;

  int? _parseIntOrNull(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  String? _nullIfBlank(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();

  Future<void> _save() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;
    final locked = _isAbnVerified(
      ref.read(profileControllerProvider).builderProfile,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .savePatches(
          builder: BuilderProfilePatch(
            // ABR-verified company name + ABN must never be altered from
            // here — leave them out of the patch while locked.
            companyName: locked
                ? const None()
                : Some((values['company_name'] as String).trim()),
            abn: locked
                ? const None()
                : Some(_nullIfBlank(values['abn'] as String?)),
            contactName: Some(_nullIfBlank(values['contact_name'] as String?)),
            contactPhone: Some(
              _nullIfBlank(values['contact_phone'] as String?),
            ),
            yearsInBusiness: Some(
              _parseIntOrNull(values['years_in_business']),
            ),
            website: Some(_nullIfBlank(values['website'] as String?)),
          ),
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
    final fallbackName = state.profile?.displayName;
    final locked = _isAbnVerified(bp);

    return EditSheetScaffold(
      title: 'Business details',
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
            const FieldLabel('YOUR NAME'),
            Gap(AppSpacing.sm.h),
            JTextField(
              name: 'contact_name',
              hint: 'Your full name',
              initialValue: bp?.contactName ?? fallbackName,
            ),
            Gap(AppSpacing.md.h),
            // ABN + Company Name lock once verified — see the rationale on
            // the legacy form (verified entity-name backfill from verify-abn).
            _VerifiedLockedField(
              label: 'COMPANY NAME',
              fieldName: 'company_name',
              initialValue: bp?.companyName,
              hint: 'e.g. Pinnacle Construct',
              locked: locked,
              requiredField: true,
            ),
            Gap(AppSpacing.md.h),
            _VerifiedLockedField(
              label: 'ABN',
              fieldName: 'abn',
              initialValue: bp?.abn,
              hint: '12 345 678 901',
              locked: locked,
              keyboardType: TextInputType.number,
            ),
            Gap(AppSpacing.md.h),
            const FieldLabel('YEARS IN BUSINESS'),
            Gap(AppSpacing.sm.h),
            JTextField(
              name: 'years_in_business',
              hint: 'e.g. 5',
              initialValue: bp?.yearsInBusiness?.toString(),
              keyboardType: TextInputType.number,
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.integer(errorText: 'Whole numbers only.'),
                FormBuilderValidators.min(0, errorText: 'Must be 0 or more.'),
                FormBuilderValidators.max(60, errorText: 'Must be 60 or fewer.'),
              ]),
            ),
            Gap(AppSpacing.md.h),
            const FieldLabel('CONTACT PHONE'),
            Gap(AppSpacing.sm.h),
            JTextField(
              name: 'contact_phone',
              hint: '+61 4 1234 5678',
              initialValue: bp?.contactPhone,
              keyboardType: TextInputType.phone,
            ),
            Gap(AppSpacing.md.h),
            const FieldLabel('WEBSITE'),
            Gap(AppSpacing.sm.h),
            JTextField(
              name: 'website',
              hint: 'https://yourcompany.com.au',
              initialValue: bp?.website,
              keyboardType: TextInputType.url,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                return FormBuilderValidators.url(
                  protocols: ['https', 'http'],
                  errorText: 'Enter a valid URL.',
                )(v);
              },
            ),
            Gap(AppSpacing.sm.h),
          ],
        ),
      ),
    );
  }
}

// Moved verbatim from profile_edit_widgets.dart (single caller lives here).

bool _isAbnVerified(BuilderProfile? bp) =>
    bp?.abn != null && bp!.abn!.trim().isNotEmpty;

/// FormBuilder text input that switches into a read-only "verified, locked"
/// state when the corresponding row already carries an ABR-confirmed value.
class _VerifiedLockedField extends StatelessWidget {
  const _VerifiedLockedField({
    required this.label,
    required this.fieldName,
    required this.initialValue,
    required this.hint,
    required this.locked,
    this.keyboardType,
    this.requiredField = false,
  });

  final String label;
  final String fieldName;
  final String? initialValue;
  final String hint;
  final bool locked;
  final TextInputType? keyboardType;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            FieldLabel(label),
            if (locked) ...[
              Gap(8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: c.verifiedBg,
                  borderRadius: BorderRadius.circular(4.r),
                  border: Border.all(color: c.verified.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.verified,
                      size: AppIconSize.micro.r,
                      color: c.verified,
                    ),
                    Gap(4.w),
                    Text(
                      'VERIFIED',
                      style: tt.labelSmall!.copyWith(
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: c.verified,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        Gap(AppSpacing.sm.h),
        JTextField(
          name: fieldName,
          hint: hint,
          initialValue: initialValue,
          enabled: !locked,
          keyboardType: keyboardType,
          validator: requiredField
              ? FormBuilderValidators.required(errorText: '$label is required.')
              : null,
        ),
        if (locked) ...[
          Gap(4.h),
          Text(
            'Locked after ABR verification. Contact support to change.',
            style: tt.bodySmall!.copyWith(
              color: c.text3,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}
