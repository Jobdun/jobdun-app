part of 'profile_edit_page.dart';

/// Parses a FormBuilder string value to int, treating null/blank as null.
/// Shared by [_save]'s saveProfile payload assembly.
int? _parseIntOrNull(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}

/// Parses a FormBuilder string value to double, treating null/blank as null.
double? _parseDoubleOrNull(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

// Form field-groups for the profile-edit page, split into a `part` so
// `profile_edit_page.dart` stays under the file-size budget. Each is a thin
// presentational grouping of the FormBuilder fields that previously lived
// inline in the page's build(). They render inside the page's FormBuilder, so
// the `name:`-keyed inputs still register against the same form state. Columns
// keep CrossAxisAlignment.start + MainAxisSize.min so layout is unchanged.

/// Builder-only fields: contact name, verified-locked company name + ABN,
/// years in business, website.
class _BuilderFields extends StatelessWidget {
  const _BuilderFields({required this.bp, required this.fallbackName});

  final BuilderProfile? bp;

  /// `profile?.displayName ?? metadataFullName` — prefill for contact name.
  final String? fallbackName;

  @override
  Widget build(BuildContext context) {
    return Column(
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
        // ABN + Company Name lock once verified. The verified entity-name
        // backfill from verify-abn mirrors the ABR record into these columns;
        // letting the user edit them post-verify would silently invalidate the
        // verification receipt (builders viewing this profile see the trust
        // signal on the COMPANY DETAILS card). "Contact support to change" is
        // the escape hatch — a dedicated change flow can land later if demand
        // justifies it.
        _VerifiedLockedField(
          label: 'COMPANY NAME',
          fieldName: 'company_name',
          initialValue: bp?.companyName,
          hint: 'e.g. Pinnacle Construct',
          locked: _isAbnVerified(bp),
          requiredField: true,
        ),
        Gap(AppSpacing.md.h),
        _VerifiedLockedField(
          label: 'ABN',
          fieldName: 'abn',
          initialValue: bp?.abn,
          hint: '12 345 678 901',
          locked: _isAbnVerified(bp),
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
        Gap(AppSpacing.md.h),
      ],
    );
  }
}

/// Trade-only fields: legal name, trade picker, years of experience, hourly
/// rate range, and the rate-visibility toggle.
class _TradeFields extends StatelessWidget {
  const _TradeFields({
    required this.tp,
    required this.metadataFullName,
    required this.tradeSlug,
    required this.tradeOther,
    required this.onPickTrade,
    required this.showTradeError,
    required this.formKey,
    required this.hourlyRateVisible,
    required this.onRateVisibilityChanged,
  });

  final TradeProfile? tp;
  final String? metadataFullName;
  final String? tradeSlug;
  final String? tradeOther;
  final VoidCallback onPickTrade;
  final bool showTradeError;
  final GlobalKey<FormBuilderState> formKey;
  final bool hourlyRateVisible;
  final ValueChanged<bool> onRateVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const FieldLabel('LEGAL NAME'),
        Gap(AppSpacing.sm.h),
        JTextField(
          name: 'full_name',
          hint: 'For invoices and verification',
          initialValue: tp?.fullName ?? metadataFullName,
          validator: FormBuilderValidators.required(
            errorText: 'Legal name is required.',
          ),
        ),
        Gap(AppSpacing.md.h),
        const FieldLabel('TRADE'),
        Gap(AppSpacing.sm.h),
        _TradePickerTile(
          slug: tradeSlug,
          otherText: tradeOther,
          onTap: onPickTrade,
          hasError: showTradeError && tradeSlug == null,
        ),
        if (showTradeError && tradeSlug == null) ...[
          Gap(4.h),
          Text(
            'Pick a trade to continue.',
            style: tt.bodySmall!.copyWith(color: c.urgent, fontSize: 12.sp),
          ),
        ],
        Gap(AppSpacing.md.h),
        const FieldLabel('YEARS OF EXPERIENCE'),
        Gap(AppSpacing.sm.h),
        JTextField(
          name: 'years_experience',
          hint: 'e.g. 8',
          initialValue: tp?.yearsExperience?.toString(),
          keyboardType: TextInputType.number,
          validator: FormBuilderValidators.compose([
            FormBuilderValidators.integer(errorText: 'Whole numbers only.'),
            FormBuilderValidators.min(0, errorText: 'Must be 0 or more.'),
            FormBuilderValidators.max(60, errorText: 'Must be 60 or fewer.'),
          ]),
        ),
        Gap(AppSpacing.md.h),
        const FieldLabel('HOURLY RATE (AUD)'),
        Gap(AppSpacing.sm.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: JTextField(
                name: 'hourly_rate_min',
                hint: 'Min',
                initialValue: tp?.hourlyRateMin?.toStringAsFixed(0),
                keyboardType: TextInputType.number,
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.numeric(errorText: 'Numbers only.'),
                  FormBuilderValidators.min(0, errorText: 'Must be 0 or more.'),
                ]),
              ),
            ),
            Gap(10.w),
            Expanded(
              child: JTextField(
                name: 'hourly_rate_max',
                hint: 'Max',
                initialValue: tp?.hourlyRateMax?.toStringAsFixed(0),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return null;
                  }
                  final max = double.tryParse(v);
                  if (max == null) return 'Numbers only.';
                  if (max < 0) return 'Must be 0 or more.';
                  final minStr =
                      formKey.currentState?.fields['hourly_rate_min']?.value
                          as String?;
                  final min = double.tryParse(minStr ?? '');
                  if (min != null && max < min) {
                    return 'Must be ≥ min.';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        Gap(AppSpacing.md.h),
        _RateVisibilityRow(
          value: hourlyRateVisible,
          onChanged: onRateVisibilityChanged,
        ),
        Gap(AppSpacing.md.h),
      ],
    );
  }
}

/// Fields shown to both roles: display name, location, builder contact phone,
/// and the about blurb.
class _CommonFields extends StatelessWidget {
  const _CommonFields({
    required this.isBuilder,
    required this.displayNameInitial,
    required this.bp,
    required this.tp,
  });

  final bool isBuilder;
  final String? displayNameInitial;
  final BuilderProfile? bp;
  final TradeProfile? tp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const FieldLabel('DISPLAY NAME'),
        Gap(AppSpacing.sm.h),
        JTextField(
          name: 'display_name',
          hint: 'Shown publicly to other users',
          initialValue: displayNameInitial,
          validator: FormBuilderValidators.required(
            errorText: 'Display name is required.',
          ),
        ),
        Gap(AppSpacing.md.h),
        ProfileLocationField(
          label: isBuilder ? 'SERVICE LOCATION' : 'BASE LOCATION',
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
        Gap(AppSpacing.md.h),
        if (isBuilder) ...[
          const FieldLabel('CONTACT PHONE'),
          Gap(AppSpacing.sm.h),
          JTextField(
            name: 'contact_phone',
            hint: '+61 4 1234 5678',
            initialValue: bp?.contactPhone,
            keyboardType: TextInputType.phone,
          ),
          Gap(AppSpacing.md.h),
        ],
        const FieldLabel('ABOUT'),
        Gap(AppSpacing.sm.h),
        JTextField(
          name: 'about',
          hint: isBuilder
              ? 'Tell tradies about your company…'
              : 'Tell builders about your experience…',
          initialValue: isBuilder ? bp?.about : tp?.about,
          maxLines: 4,
        ),
      ],
    );
  }
}

/// VERIFICATION + (trade-only) PORTFOLIO section. Status rows for the slots the
/// T1 completeness banner grades on — each row reads the same field the SQL
/// view does so the screen and the banner always agree.
class _VerificationSection extends StatelessWidget {
  const _VerificationSection({
    required this.isBuilder,
    required this.phoneVerified,
    required this.hasLicence,
  });

  final bool isBuilder;
  final bool phoneVerified;
  final bool hasLicence;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Gap(AppSpacing.lg.h),
        const FieldLabel('VERIFICATION'),
        Gap(AppSpacing.sm.h),
        _StatusRow(
          icon: AppIcons.phone,
          label: 'Phone',
          done: phoneVerified,
          ctaLabel: 'VERIFY',
          onCta: () => context.push('/profile/verify-phone'),
        ),
        if (!isBuilder) ...[
          Gap(8.h),
          _StatusRow(
            icon: AppIcons.document,
            label: 'Trade licence',
            done: hasLicence,
            ctaLabel: 'UPLOAD',
            onCta: () => context.push('/verification'),
          ),
          Gap(AppSpacing.lg.h),
          const FieldLabel('PORTFOLIO'),
          Gap(AppSpacing.sm.h),
          const PortfolioStrip(),
        ],
      ],
    );
  }
}
