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
import '../../../../core/design/widgets/page_header.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/trade_categories_provider.dart';
import '../widgets/portfolio_strip.dart';
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
    final file = await ImageUploadService.pickCropCompress(
      source: source,
      aspect: ImageAspect.square,
    );
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

    int? parseIntOrNull(Object? v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      return int.tryParse(s);
    }

    final ok = await ref
        .read(profileControllerProvider.notifier)
        .saveProfile(
          role: role,
          displayName: values['display_name'] as String,
          suburb: values['suburb'] as String,
          auState: values['state'] as String?,
          postcode: values['postcode'] as String?,
          about: values['about'] as String?,
          companyName: values['company_name'] as String?,
          abn: values['abn'] as String?,
          contactName: values['contact_name'] as String?,
          contactPhone: values['contact_phone'] as String?,
          yearsInBusiness: parseIntOrNull(values['years_in_business']),
          fullName: values['full_name'] as String?,
          primaryTrade: _tradeSlug,
          tradeOther: _tradeOther,
          yearsExperience: parseIntOrNull(values['years_experience']),
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
                        _FormField(
                          name: 'contact_name',
                          hint: 'Your full name',
                          initialValue:
                              bp?.contactName ??
                              profile?.displayName ??
                              _metadataFullName,
                        ),
                        Gap(AppSpacing.md.h),
                        const FieldLabel('COMPANY NAME'),
                        Gap(AppSpacing.sm.h),
                        _FormField(
                          name: 'company_name',
                          hint: 'e.g. Pinnacle Construct',
                          initialValue: bp?.companyName,
                          validator: FormBuilderValidators.required(
                            errorText: 'Company name is required.',
                          ),
                        ),
                        Gap(AppSpacing.md.h),
                        const FieldLabel('ABN'),
                        Gap(AppSpacing.sm.h),
                        _FormField(
                          name: 'abn',
                          hint: '12 345 678 901',
                          initialValue: bp?.abn,
                          keyboardType: TextInputType.number,
                        ),
                        Gap(AppSpacing.md.h),
                        const FieldLabel('YEARS IN BUSINESS'),
                        Gap(AppSpacing.sm.h),
                        _FormField(
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
                      ] else ...[
                        const FieldLabel('LEGAL NAME'),
                        Gap(AppSpacing.sm.h),
                        _FormField(
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
                        _FormField(
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
                      ],
                      const FieldLabel('DISPLAY NAME'),
                      Gap(AppSpacing.sm.h),
                      _FormField(
                        name: 'display_name',
                        hint: 'Shown publicly to other users',
                        initialValue: profile?.displayName ?? _metadataFullName,
                        validator: FormBuilderValidators.required(
                          errorText: 'Display name is required.',
                        ),
                      ),
                      Gap(AppSpacing.md.h),
                      FieldLabel(isBuilder ? 'SERVICE SUBURB' : 'BASE SUBURB'),
                      Gap(AppSpacing.sm.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: _FormField(
                              name: 'suburb',
                              hint: 'Suburb',
                              initialValue: isBuilder
                                  ? bp?.serviceSuburb
                                  : tp?.baseSuburb,
                              validator: FormBuilderValidators.required(
                                errorText: 'Suburb is required.',
                              ),
                            ),
                          ),
                          Gap(10.w),
                          Expanded(
                            flex: 2,
                            child: _FormField(
                              name: 'state',
                              hint: 'State',
                              initialValue: isBuilder
                                  ? bp?.serviceState
                                  : tp?.baseState,
                            ),
                          ),
                          Gap(10.w),
                          Expanded(
                            flex: 3,
                            child: _FormField(
                              name: 'postcode',
                              hint: 'Postcode',
                              initialValue: isBuilder
                                  ? bp?.servicePostcode
                                  : tp?.basePostcode,
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
                      Gap(AppSpacing.md.h),
                      if (isBuilder) ...[
                        const FieldLabel('CONTACT PHONE'),
                        Gap(AppSpacing.sm.h),
                        _FormField(
                          name: 'contact_phone',
                          hint: '+61 4 1234 5678',
                          initialValue: bp?.contactPhone,
                          keyboardType: TextInputType.phone,
                        ),
                        Gap(AppSpacing.md.h),
                      ],
                      const FieldLabel('ABOUT'),
                      Gap(AppSpacing.sm.h),
                      _FormField(
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

// FormBuilder-aware text field with the bordered-surface chrome that matches
// the rest of /profile/edit. Helper-space is reserved so validation errors
// don't push the form's layout around.
class _FormField extends StatelessWidget {
  const _FormField({
    required this.name,
    required this.hint,
    this.initialValue,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String name;
  final String hint;
  final String? initialValue;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    // The themed OutlineInputBorder owns the box, so Material renders the
    // validation error BELOW/outside the field instead of inside the border.
    // Mirrors JTextField (the auth-flow pattern) and MASTER “Input Fields”.
    return FormBuilderTextField(
      name: name,
      initialValue: initialValue,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: tt.bodyLarge!.copyWith(
        color: c.text1,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        // Reserve helper/error space so layout doesn't jump on validation.
        helperText: ' ',
        helperMaxLines: 2,
        errorMaxLines: 2,
      ),
    );
  }
}

// Tappable input-shaped tile that mirrors _FormField's chrome and opens the
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
