import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/avatar_block.dart';
import '../../../../core/design/widgets/bottom_action_bar.dart';
import '../../../../core/design/widgets/field_label.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_switch.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/services/places_service.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/builder_profile.dart';
import '../providers/profile_provider.dart';
import '../providers/trade_categories_provider.dart';
import '../widgets/portfolio_strip.dart';
import '../widgets/profile_location_field.dart';
import '../widgets/trade_category_picker.dart';

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  final _formKey = GlobalKey<FormBuilderState>();

  // Trade picker is state-managed (not a FormBuilder field) — validated in
  // _save alongside the FormBuilder validators.
  String? _tradeSlug;
  String? _tradeOther;
  bool _showTradeError = false;

  // Hourly-rate visibility toggle is local state (default true). FormBuilder
  // doesn't ship a switch field that matches JSwitch's chrome, and the value
  // is a simple bool so we hand-roll it.
  bool? _hourlyRateVisible;

  // Fresh sign-ups land here with an empty profile row; fall back to the
  // name they typed at sign-up (stored on auth.users.user_metadata.full_name
  // by register_page) so they don't retype it.
  String? get _metadataFullName {
    final raw =
        SupabaseConfig.client.auth.currentUser?.userMetadata?['full_name'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }

  @override
  void initState() {
    super.initState();
    final tp = ref.read(profileControllerProvider).tradeProfile;
    if (tp != null && tp.primaryTrade.isNotEmpty) {
      _tradeSlug = tp.primaryTrade;
    }
    _hourlyRateVisible = tp?.hourlyRateVisible ?? true;
  }

  Future<void> _pickTrade() async {
    final selection = await showTradeCategoryPicker(
      context,
      initialSlug: _tradeSlug,
      initialOtherText: _tradeOther,
    );
    if (selection == null) return;
    setState(() {
      _tradeSlug = selection.slug;
      _tradeOther = selection.slug == 'other' ? selection.otherText : null;
      _showTradeError = false;
    });
  }

  Future<void> _pickAvatar() async {
    final hasAvatar =
        ref.read(profileControllerProvider).profile?.avatarUrl != null;
    final action = await showJSheet<_AvatarAction>(
      context: context,
      backgroundColor: context.c.card,
      builder: (_) => _AvatarPickerSheet(hasAvatar: hasAvatar),
    );
    if (action == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(profileControllerProvider.notifier);

    if (action == _AvatarAction.remove) {
      final ok = await controller.removeAvatar();
      if (!mounted) return;
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't remove avatar.")),
        );
      }
      return;
    }

    final source = action == _AvatarAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    File? file;
    try {
      file = await ImageUploadService.pickCropCompress(
        source: source,
        aspect: ImageAspect.square,
      );
    } on UploadGuardException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (file == null || !mounted) return;

    final ok = await controller.uploadAvatar(file);
    if (!mounted) return;
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't upload avatar.")),
      );
    }
  }

  Future<void> _save() async {
    final auth = ref.read(authControllerProvider);
    final role = auth.role;
    if (role == null) return;

    final formOk = _formKey.currentState?.saveAndValidate() ?? false;
    final isTrade = role == UserRole.trade;
    final tradeMissing = isTrade && (_tradeSlug == null || _tradeSlug!.isEmpty);
    if (tradeMissing) {
      setState(() => _showTradeError = true);
    }
    if (!formOk || tradeMissing) return;

    final values = _formKey.currentState!.value;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    // PLACES_ENABLED branch — values['place'] is a JPlaceResult set by
    // JPlaceField. Split it back into the suburb/state/postcode the controller
    // already expects, and tag-on the new lat/lng + place_id + formatted_address.
    final pickedPlace = values['place'] as JPlaceResult?;
    final String resolvedSuburb =
        pickedPlace?.suburb ?? (values['suburb'] as String?) ?? '';
    final String? resolvedState =
        pickedPlace?.state ?? values['state'] as String?;
    final String? resolvedPostcode =
        pickedPlace?.postcode ?? values['postcode'] as String?;

    int? parseIntOrNull(Object? v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      return int.tryParse(s);
    }

    double? parseDoubleOrNull(Object? v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      return double.tryParse(s);
    }

    final ok = await ref
        .read(profileControllerProvider.notifier)
        .saveProfile(
          role: role,
          displayName: values['display_name'] as String,
          suburb: resolvedSuburb,
          auState: resolvedState,
          postcode: resolvedPostcode,
          formattedAddress: pickedPlace?.formattedAddress,
          placeId: pickedPlace?.placeId,
          latitude: pickedPlace?.latitude,
          longitude: pickedPlace?.longitude,
          about: values['about'] as String?,
          companyName: values['company_name'] as String?,
          abn: values['abn'] as String?,
          contactName: values['contact_name'] as String?,
          contactPhone: values['contact_phone'] as String?,
          yearsInBusiness: parseIntOrNull(values['years_in_business']),
          website: values['website'] as String?,
          fullName: values['full_name'] as String?,
          primaryTrade: _tradeSlug,
          tradeOther: _tradeOther,
          yearsExperience: parseIntOrNull(values['years_experience']),
          hourlyRateMin: parseDoubleOrNull(values['hourly_rate_min']),
          hourlyRateMax: parseDoubleOrNull(values['hourly_rate_max']),
          hourlyRateVisible: _hourlyRateVisible,
        );

    if (!mounted) return;
    if (ok) {
      router.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                AppIcons.successCircle,
                size: 18.r,
                color: Colors.white, // intentional: white-on-success
              ),
              Gap(10.w),
              Text(
                'Profile updated.',
                style: tt.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white, // intentional: white-on-success
                ),
              ),
            ],
          ),
          backgroundColor: c.verified,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            "Couldn't save changes. Try again.",
            style: tt.bodyMedium!.copyWith(
              color: Colors.white, // intentional: white-on-error
            ),
          ),
          backgroundColor: c.urgent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final authState = ref.watch(authControllerProvider);
    final isBuilder = authState.role == UserRole.builder;
    final profileState = ref.watch(profileControllerProvider);
    final profile = profileState.profile;
    final bp = profileState.builderProfile;
    final tp = profileState.tradeProfile;
    final isSaving = profileState.isLoading;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar
            Container(
              color: c.card,
              padding: EdgeInsets.fromLTRB(4.w, 8.h, 20.w, 12.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(AppIcons.back, size: 22.r, color: c.text1),
                  ),
                  const Expanded(
                    child: PageHeader(
                      eyebrow: 'EDIT PROFILE',
                      title: 'Your details',
                      size: PageHeaderSize.sub,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),

            Expanded(
              child: FormBuilder(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20.w,
                    20.h,
                    20.w,
                    AppSpacing.lg.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AvatarHeader(
                        avatarUrl: profile?.avatarUrl,
                        initials: StringUtils.initials(
                          profile?.displayName ?? '?',
                        ),
                        isUploading: profileState.isUploadingAvatar,
                        onTap: profileState.isUploadingAvatar
                            ? null
                            : _pickAvatar,
                      ),
                      Gap(AppSpacing.lg.h),
                      if (isBuilder) ...[
                        const FieldLabel('YOUR NAME'),
                        Gap(AppSpacing.sm.h),
                        JTextField(
                          name: 'contact_name',
                          hint: 'Your full name',
                          initialValue:
                              bp?.contactName ??
                              profile?.displayName ??
                              _metadataFullName,
                        ),
                        Gap(AppSpacing.md.h),
                        // ABN + Company Name lock once verified. The verified
                        // entity-name backfill from verify-abn mirrors the
                        // ABR record into these columns; letting the user
                        // edit them post-verify would silently invalidate
                        // the verification receipt (builders viewing this
                        // profile see the trust signal on the COMPANY DETAILS
                        // card). "Contact support to change" is the escape
                        // hatch — a dedicated change flow can land later if
                        // demand justifies it.
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
                            FormBuilderValidators.integer(
                              errorText: 'Whole numbers only.',
                            ),
                            FormBuilderValidators.min(
                              0,
                              errorText: 'Must be 0 or more.',
                            ),
                            FormBuilderValidators.max(
                              60,
                              errorText: 'Must be 60 or fewer.',
                            ),
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
                      ] else ...[
                        const FieldLabel('LEGAL NAME'),
                        Gap(AppSpacing.sm.h),
                        JTextField(
                          name: 'full_name',
                          hint: 'For invoices and verification',
                          initialValue: tp?.fullName ?? _metadataFullName,
                          validator: FormBuilderValidators.required(
                            errorText: 'Legal name is required.',
                          ),
                        ),
                        Gap(AppSpacing.md.h),
                        const FieldLabel('TRADE'),
                        Gap(AppSpacing.sm.h),
                        _TradePickerTile(
                          slug: _tradeSlug,
                          otherText: _tradeOther,
                          onTap: _pickTrade,
                          hasError: _showTradeError && _tradeSlug == null,
                        ),
                        if (_showTradeError && _tradeSlug == null) ...[
                          Gap(4.h),
                          Text(
                            'Pick a trade to continue.',
                            style: tt.bodySmall!.copyWith(
                              color: c.urgent,
                              fontSize: 12.sp,
                            ),
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
                            FormBuilderValidators.integer(
                              errorText: 'Whole numbers only.',
                            ),
                            FormBuilderValidators.min(
                              0,
                              errorText: 'Must be 0 or more.',
                            ),
                            FormBuilderValidators.max(
                              60,
                              errorText: 'Must be 60 or fewer.',
                            ),
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
                                initialValue: tp?.hourlyRateMin
                                    ?.toStringAsFixed(0),
                                keyboardType: TextInputType.number,
                                validator: FormBuilderValidators.compose([
                                  FormBuilderValidators.numeric(
                                    errorText: 'Numbers only.',
                                  ),
                                  FormBuilderValidators.min(
                                    0,
                                    errorText: 'Must be 0 or more.',
                                  ),
                                ]),
                              ),
                            ),
                            Gap(10.w),
                            Expanded(
                              child: JTextField(
                                name: 'hourly_rate_max',
                                hint: 'Max',
                                initialValue: tp?.hourlyRateMax
                                    ?.toStringAsFixed(0),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return null;
                                  }
                                  final max = double.tryParse(v);
                                  if (max == null) return 'Numbers only.';
                                  if (max < 0) return 'Must be 0 or more.';
                                  final minStr =
                                      _formKey
                                              .currentState
                                              ?.fields['hourly_rate_min']
                                              ?.value
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
                          value: _hourlyRateVisible ?? true,
                          onChanged: (v) =>
                              setState(() => _hourlyRateVisible = v),
                        ),
                        Gap(AppSpacing.md.h),
                      ],
                      const FieldLabel('DISPLAY NAME'),
                      Gap(AppSpacing.sm.h),
                      JTextField(
                        name: 'display_name',
                        hint: 'Shown publicly to other users',
                        initialValue: profile?.displayName ?? _metadataFullName,
                        validator: FormBuilderValidators.required(
                          errorText: 'Display name is required.',
                        ),
                      ),
                      Gap(AppSpacing.md.h),
                      ProfileLocationField(
                        label: isBuilder ? 'SERVICE LOCATION' : 'BASE LOCATION',
                        legacyInitial: (
                          suburb: isBuilder
                              ? bp?.serviceSuburb
                              : tp?.baseSuburb,
                          state: isBuilder ? bp?.serviceState : tp?.baseState,
                          postcode: isBuilder
                              ? bp?.servicePostcode
                              : tp?.basePostcode,
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

                      // ── Verification + portfolio ─────────────────────
                      // Status rows for the slots the T1 completeness banner
                      // grades on. Each row reads the same field the SQL view
                      // does so the screen and the banner always agree.
                      Gap(AppSpacing.lg.h),
                      const FieldLabel('VERIFICATION'),
                      Gap(AppSpacing.sm.h),
                      _StatusRow(
                        icon: AppIcons.phone,
                        label: 'Phone',
                        done: profile?.isPhoneVerified ?? false,
                        ctaLabel: 'VERIFY',
                        onCta: () => context.push('/profile/verify-phone'),
                      ),
                      if (!isBuilder) ...[
                        Gap(8.h),
                        _StatusRow(
                          icon: AppIcons.document,
                          label: 'Trade licence',
                          done: tp?.hasLicence ?? false,
                          ctaLabel: 'UPLOAD',
                          onCta: () => context.push('/verification'),
                        ),
                        Gap(AppSpacing.lg.h),
                        const FieldLabel('PORTFOLIO'),
                        Gap(AppSpacing.sm.h),
                        const PortfolioStrip(),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            BottomActionBar(
              primary: JButton(
                label: isSaving ? 'SAVING...' : 'SAVE CHANGES',
                isLoading: isSaving,
                onPressed: isSaving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Tappable input-shaped tile that mirrors JTextField's chrome and opens the
// TradeCategoryPicker. Resolves display label from the cached categories list;
// falls back to the slug if the row isn't in the live list (renamed category).
class _TradePickerTile extends ConsumerWidget {
  const _TradePickerTile({
    required this.slug,
    required this.otherText,
    required this.onTap,
    required this.hasError,
  });

  final String? slug;
  final String? otherText;
  final VoidCallback onTap;
  final bool hasError;

  String _label(AsyncValue<dynamic> async) {
    if (slug == null) return 'Pick your trade';
    if (slug == 'other') {
      return (otherText == null || otherText!.isEmpty)
          ? 'Other'
          : 'Other — $otherText';
    }
    return async.maybeWhen(
      data: (rows) {
        final list = rows as List<dynamic>;
        for (final r in list) {
          if (r.slug == slug) return r.displayName as String;
        }
        return slug!;
      },
      orElse: () => slug!,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final async = ref.watch(tradeCategoriesProvider);
    final hasValue = slug != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input.r),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.input.r),
            border: Border.all(color: hasError ? c.urgent : c.border),
          ),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _label(async),
                  style: tt.bodyLarge!.copyWith(
                    color: hasValue ? c.text1 : c.text3,
                  ),
                ),
              ),
              Icon(AppIcons.chevronDown, size: 16.r, color: c.text3),
            ],
          ),
        ),
      ),
    );
  }
}

// Two-up: label + helper text on the left, JSwitch on the right. The
// helper line changes wording when the toggle flips so the affordance and
// its consequence sit next to each other.
class _RateVisibilityRow extends StatelessWidget {
  const _RateVisibilityRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.input.r),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Show my rate to builders',
                  style: tt.bodyMedium!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Gap(2.h),
                Text(
                  value
                      ? 'Your hourly range appears on your applications.'
                      : 'Builders see "Rate on request" instead.',
                  style: tt.bodySmall!.copyWith(color: c.text3),
                ),
              ],
            ),
          ),
          Gap(10.w),
          JSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// Tappable avatar at the top of /profile/edit. Pulls double duty as the
// affordance for editing the avatar AND as the visual confirmation of the
// current avatar — tap opens the picker sheet, the upload spinner overlays
// in place. Hero tag matches the profile page's header avatar so the
// transition flows when that page wires its own Hero in a follow-up.
class _AvatarHeader extends StatelessWidget {
  const _AvatarHeader({
    required this.avatarUrl,
    required this.initials,
    required this.isUploading,
    required this.onTap,
  });

  final String? avatarUrl;
  final String initials;
  final bool isUploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Hero(
              tag: 'profile-avatar',
              child: Stack(
                children: [
                  avatarUrl != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatarUrl!,
                            width: 96.r,
                            height: 96.r,
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                AvatarBlock(initials: initials, size: 96),
                            errorWidget: (_, _, _) =>
                                AvatarBlock(initials: initials, size: 96),
                          ),
                        )
                      : AvatarBlock(initials: initials, size: 96),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 30.r,
                      height: 30.r,
                      decoration: BoxDecoration(
                        color: c.action,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.card, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        AppIcons.camera,
                        size: 14.r,
                        color: Colors
                            .white, // intentional: white-on-orange action chip
                      ),
                    ),
                  ),
                  if (isUploading)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                          color: Colors
                              .white, // intentional: white-on-dark-overlay
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Gap(AppSpacing.sm.h),
          Text(
            'Tap to change photo',
            style: tt.labelSmall!.copyWith(
              color: c.text3,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

enum _AvatarAction { camera, gallery, remove }

class _AvatarPickerSheet extends StatelessWidget {
  const _AvatarPickerSheet({required this.hasAvatar});

  final bool hasAvatar;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final radius = BorderRadius.vertical(
      top: Radius.circular(AppRadius.card.r),
    );
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(color: c.card, borderRadius: radius),
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 12.h),
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            _SheetAction(
              icon: AppIcons.camera,
              label: 'Take photo',
              onTap: () => Navigator.of(context).pop(_AvatarAction.camera),
            ),
            _SheetAction(
              icon: AppIcons.image,
              label: 'Pick from gallery',
              onTap: () => Navigator.of(context).pop(_AvatarAction.gallery),
            ),
            if (hasAvatar)
              _SheetAction(
                icon: AppIcons.trash,
                label: 'Remove photo',
                destructive: true,
                onTap: () => Navigator.of(context).pop(_AvatarAction.remove),
              ),
            Gap(8.h),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                child: Text(
                  'CANCEL',
                  textAlign: TextAlign.center,
                  style: tt.labelMedium!.copyWith(
                    color: c.text3,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final color = destructive ? c.urgent : c.text1;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.input.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, size: 22.r, color: color),
            Gap(14.w),
            Text(
              label,
              style: tt.bodyLarge!.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Inline status row used in the VERIFICATION section. Done = check mark in
// the verified accent; not-done = small uppercase CTA that pushes the
// relevant fix-it screen.
class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.done,
    required this.ctaLabel,
    required this.onCta,
  });

  final IconData icon;
  final String label;
  final bool done;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.input.r),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18.r, color: done ? c.verified : c.text3),
          Gap(12.w),
          Expanded(
            child: Text(label, style: tt.bodyMedium!.copyWith(color: c.text1)),
          ),
          if (done)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.successCircle, size: 16.r, color: c.verified),
                Gap(6.w),
                Text(
                  'VERIFIED',
                  style: tt.labelSmall!.copyWith(
                    color: c.verified,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            )
          else
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCta,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                child: Text(
                  ctaLabel,
                  style: tt.labelSmall!.copyWith(
                    color: c.action,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// True when the builder profile carries an ABN that was mirrored in from a
/// successful verify-abn run — used to lock Company Name + ABN inputs.
/// We treat `bp.abn != null` as proof of verification because the only path
/// that writes to that column is the Edge Function's post-ABR mirror.
bool _isAbnVerified(BuilderProfile? bp) =>
    bp?.abn != null && bp!.abn!.trim().isNotEmpty;

/// FormBuilder text input that switches into a read-only "verified, locked"
/// state when the corresponding row already carries an ABR-confirmed value.
/// Renders the same JTextField shell either way so layout stays stable —
/// the lock state surfaces via a small "✓ Verified" chip next to the label,
/// the disabled input itself, and a "Contact support to change" hint line.
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
                    Icon(AppIcons.verified, size: 11.r, color: c.verified),
                    Gap(4.w),
                    Text(
                      'VERIFIED',
                      style: tt.labelSmall!.copyWith(
                        fontSize: 9.sp,
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
              fontSize: 11.sp,
              color: c.text3,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}
