import 'dart:io';

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
import '../../domain/entities/trade_profile.dart';
import '../providers/profile_provider.dart';
import '../providers/trade_categories_provider.dart';
import '../widgets/portfolio_strip.dart';
import '../widgets/profile_edit_avatar.dart';
import '../widgets/profile_location_field.dart';
import '../widgets/trade_category_picker.dart';

part 'profile_edit_widgets.dart';
part 'profile_edit_form_fields.dart';

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

  // Sticky avatar error — the controller wipes its `error` on the next
  // mutation, but the snackbar fades after 4s. Keeping a local copy means
  // a failed upload stays visible under the avatar (with a retry chip)
  // until the user picks again.
  String? _avatarError;

  // Sticky save error — same reasoning, surfaces a persistent red bar
  // above the BottomActionBar so the user sees what broke after the
  // snackbar fades.
  String? _saveError;

  // Bumped after every successful avatar upload / remove. Threaded into
  // CachedNetworkImage's `cacheKey` so the same Supabase storage URL
  // re-fetches when the file behind it changes (Supabase upserts replace
  // the object in place; the URL doesn't change).
  int _avatarCacheGen = 0;

  // Set true once the in-flight initial loadProfile() resolves OR we
  // detect the profile was already loaded by /home or /profile. Gates
  // the page-level loading view so we don't flash an empty form on
  // first paint.
  bool _readyToRender = false;

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
    final initial = ref.read(profileControllerProvider);
    final tp = initial.tradeProfile;
    if (tp != null && tp.primaryTrade.isNotEmpty) {
      _tradeSlug = tp.primaryTrade;
    }
    _hourlyRateVisible = tp?.hourlyRateVisible ?? true;
    // If /home or /profile already loaded the row, skip the spinner —
    // straight to the form. Otherwise fire a fresh load so deep-linking
    // into /profile/edit doesn't render an empty form.
    if (initial.profile != null) {
      _readyToRender = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await ref.read(profileControllerProvider.notifier).loadProfile();
        if (!mounted) return;
        setState(() => _readyToRender = true);
      });
    }
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
    final action = await showJSheet<ProfileEditAvatarAction>(
      context: context,
      backgroundColor: context.c.card,
      builder: (_) => ProfileEditAvatarPickerSheet(hasAvatar: hasAvatar),
    );
    if (action == null || !mounted) return;

    // Tapping the avatar to retry should clear the sticky error so the chip
    // doesn't linger after a successful retry.
    setState(() => _avatarError = null);

    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(profileControllerProvider.notifier);

    if (action == ProfileEditAvatarAction.remove) {
      final ok = await controller.removeAvatar();
      if (!mounted) return;
      if (ok) {
        setState(() => _avatarCacheGen++);
      } else {
        setState(() => _avatarError = "Couldn't remove photo — tap to retry.");
        messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't remove avatar.")),
        );
      }
      return;
    }

    final source = action == ProfileEditAvatarAction.camera
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
      setState(() => _avatarError = error.message);
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (file == null || !mounted) return;

    final ok = await controller.uploadAvatar(file);
    if (!mounted) return;
    if (ok) {
      setState(() => _avatarCacheGen++);
    } else {
      setState(() => _avatarError = "Upload failed — tap to retry.");
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't upload avatar.")),
      );
    }
  }

  Future<void> _save() async {
    final auth = ref.read(authControllerProvider);
    final role = auth.role;
    if (role == null) return;

    // Clear last save error the moment the user tries again — keeps the
    // persistent banner honest about which attempt the error belongs to.
    setState(() => _saveError = null);

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
          yearsInBusiness: _parseIntOrNull(values['years_in_business']),
          website: values['website'] as String?,
          fullName: values['full_name'] as String?,
          primaryTrade: _tradeSlug,
          tradeOther: _tradeOther,
          yearsExperience: _parseIntOrNull(values['years_experience']),
          hourlyRateMin: _parseDoubleOrNull(values['hourly_rate_min']),
          hourlyRateMax: _parseDoubleOrNull(values['hourly_rate_max']),
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
                size: AppIconSize.md.r,
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
      final controllerError = ref.read(profileControllerProvider).error?.trim();
      final message = (controllerError != null && controllerError.isNotEmpty)
          ? controllerError
          : "Couldn't save changes. Try again.";
      setState(() => _saveError = message);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            message,
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

    // Disambiguate the controller's single `isLoading` flag. It's flipped
    // by both loadProfile() and saveProfile() — treating it as "saving"
    // makes the SAVE button spin during a fresh page load. Scope the
    // saving signal to "we already have a profile in hand" so the button
    // only spins during an actual save.
    final isInitialLoading =
        profileState.isLoading && profile == null && !_readyToRender;
    final isSaving = profileState.isLoading && profile != null;
    final initialLoadFailed =
        !isInitialLoading && profile == null && _readyToRender;

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
                    icon: Icon(
                      AppIcons.back,
                      size: AppIconSize.md.r,
                      color: c.text1,
                    ),
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

            if (isInitialLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      Gap(AppSpacing.md.h),
                      Text(
                        'Loading your profile…',
                        style: tt.bodyMedium!.copyWith(color: c.text2),
                      ),
                    ],
                  ),
                ),
              )
            else if (initialLoadFailed)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          AppIcons.urgent,
                          size: AppIconSize.feature.r,
                          color: c.urgent,
                        ),
                        Gap(AppSpacing.sm.h),
                        Text(
                          "Couldn't load your profile",
                          style: tt.titleMedium!.copyWith(color: c.text1),
                        ),
                        Gap(4.h),
                        Text(
                          profileState.error ??
                              'Check your connection and try again.',
                          textAlign: TextAlign.center,
                          style: tt.bodySmall!.copyWith(color: c.text2),
                        ),
                        Gap(AppSpacing.lg.h),
                        SizedBox(
                          width: 180.w,
                          child: JButton(
                            label: 'RETRY',
                            isLoading: profileState.isLoading,
                            onPressed: profileState.isLoading
                                ? null
                                : () => ref
                                      .read(profileControllerProvider.notifier)
                                      .loadProfile(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
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
                        ProfileEditAvatarHeader(
                          avatarUrl: profile?.avatarUrl,
                          initials: StringUtils.initials(
                            profile?.displayName ?? '?',
                          ),
                          isUploading: profileState.isUploadingAvatar,
                          cacheGeneration: _avatarCacheGen,
                          errorMessage: _avatarError,
                          onTap: profileState.isUploadingAvatar
                              ? null
                              : _pickAvatar,
                        ),
                        Gap(AppSpacing.lg.h),
                        if (isBuilder)
                          _BuilderFields(
                            bp: bp,
                            fallbackName:
                                profile?.displayName ?? _metadataFullName,
                          )
                        else
                          _TradeFields(
                            tp: tp,
                            metadataFullName: _metadataFullName,
                            tradeSlug: _tradeSlug,
                            tradeOther: _tradeOther,
                            onPickTrade: _pickTrade,
                            showTradeError: _showTradeError,
                            formKey: _formKey,
                            hourlyRateVisible: _hourlyRateVisible ?? true,
                            onRateVisibilityChanged: (v) =>
                                setState(() => _hourlyRateVisible = v),
                          ),
                        _CommonFields(
                          isBuilder: isBuilder,
                          displayNameInitial:
                              profile?.displayName ?? _metadataFullName,
                          bp: bp,
                          tp: tp,
                        ),
                        _VerificationSection(
                          isBuilder: isBuilder,
                          phoneVerified: profile?.isPhoneVerified ?? false,
                          hasLicence: tp?.hasLicence ?? false,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_saveError != null)
                _SaveErrorBanner(
                  message: _saveError!,
                  onDismiss: () => setState(() => _saveError = null),
                ),
              BottomActionBar(
                primary: JButton(
                  // JButton swaps content to spinner-only when isLoading
                  // is true (j_button.dart:67), so passing a "SAVING..."
                  // label here is dead — stick to a single stable label.
                  label: 'SAVE CHANGES',
                  isLoading: isSaving,
                  onPressed: isSaving ? null : _save,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
