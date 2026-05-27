import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/colors.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../core/design/widgets/avatar_block.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_card.dart';
import '../../../../core/design/widgets/j_chip.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/design/widgets/j_switch.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/logout_confirm_sheet.dart';
import '../../../verification/domain/entities/verification.dart';
import '../../../verification/presentation/providers/verifications_provider.dart';
import '../../../verification/presentation/widgets/verification_receipts.dart';
import '../../domain/entities/builder_profile.dart';
import '../../domain/entities/trade_profile.dart';
import '../providers/profile_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(profileControllerProvider.notifier).loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final authState = ref.watch(authControllerProvider);
    final profileState = ref.watch(profileControllerProvider);

    final role = authState.role;
    final isBuilder = role == UserRole.builder;
    final email = authState.email ?? '';

    final displayName =
        profileState.profile?.displayName ?? StringUtils.nameFromEmail(email);
    final initials = StringUtils.initials(displayName);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _ProfileHeader(
                initials: initials,
                displayName: displayName,
                email: email,
                role: role,
                avatarUrl: profileState.profile?.avatarUrl,
                isUploadingAvatar: profileState.isUploadingAvatar,
              ),
            ),
            SliverToBoxAdapter(child: Gap(AppSpacing.md.h)),
            SliverToBoxAdapter(
              child: JSkeletonList(
                enabled: profileState.isLoading,
                child: isBuilder
                    ? _BuilderProfile(profile: profileState.builderProfile)
                    : _TradeProfile(profile: profileState.tradeProfile),
              ),
            ),
            SliverToBoxAdapter(child: Gap(AppSpacing.md.h)),
            const SliverToBoxAdapter(child: _SettingsSection()),
            SliverToBoxAdapter(child: Gap(AppSpacing.lg.h)),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: JButton(
                  label: 'SIGN OUT',
                  variant: JButtonVariant.secondary,
                  onPressed: () => showLogoutSheet(context, ref),
                ),
              ),
            ),
            SliverToBoxAdapter(child: Gap(AppSpacing.xl.h)),
          ],
        ),
      ),
    );
  }
}

// ── Profile Header ─────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.initials,
    required this.displayName,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.isUploadingAvatar = false,
  });

  final String initials;
  final String displayName;
  final String email;
  final UserRole? role;
  final String? avatarUrl;
  final bool isUploadingAvatar;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      color: c.card,
      padding: EdgeInsets.fromLTRB(
        20.w,
        AppSpacing.lg.h,
        20.w,
        AppSpacing.lg.h,
      ),
      child: Row(
        children: [
          Stack(
            children: [
              avatarUrl != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl!,
                        width: 72.r,
                        height: 72.r,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            AvatarBlock(initials: initials, size: 72),
                        errorWidget: (_, _, _) =>
                            AvatarBlock(initials: initials, size: 72),
                      ),
                    )
                  : AvatarBlock(initials: initials, size: 72),
              if (isUploadingAvatar)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(
                      color: Colors.white, // intentional: white-on-dark-overlay
                      strokeWidth: 2,
                    ),
                  ),
                ),
            ],
          ),
          Gap(AppSpacing.md.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: tt.titleMedium!.copyWith(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: c.text1,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/profile/edit'),
                      child: Container(
                        height: 36.h,
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        decoration: BoxDecoration(
                          color: c.surfaceRaised,
                          borderRadius: BorderRadius.circular(AppRadius.chip.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(AppIcons.edit, size: 16.r, color: c.text1),
                            Gap(6.w),
                            Text(
                              'EDIT',
                              style: tt.labelSmall!.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: c.text1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Gap(4.h),
                Text(email, style: tt.bodyMedium!.copyWith(color: c.text3)),
                if (role != null) ...[
                  Gap(AppSpacing.sm.h),
                  JChip(label: role!.label),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Builder Profile ────────────────────────────────────────────────────────────

class _BuilderProfile extends ConsumerWidget {
  const _BuilderProfile({this.profile});

  final BuilderProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final p = profile;

    final rating = p?.averageRating?.toStringAsFixed(1) ?? '—';
    final reviews = (p?.ratingCount ?? 0).toString();
    final jobsPosted = (p?.totalJobsPosted ?? 0).toString();

    final companyName = _blank(p?.companyName);
    final abn = _formatAbn(p?.abn);
    final location = _blank(p?.displayLocation);
    final website = _blank(p?.website);

    // Profile-level identity signals — distinct from the business-level ABN
    // verification rendered in the WHAT'S BEEN CHECKED card below.
    final userProfile = ref.watch(
      profileControllerProvider.select((s) => s.profile),
    );
    final userPhone = _formatPhone(userProfile?.phone);
    final phoneVerified = userProfile?.isPhoneVerified ?? false;

    // Contact row prefers an explicit business contact_phone the builder set
    // on /profile/edit; otherwise falls back to the verified primary phone
    // so the row isn't useless on a brand-new profile. The verified tick
    // surfaces only on the fallback (the primary phone is the one we
    // actually verified — contact_phone is self-attested).
    final contactPhone = _formatPhone(p?.contactPhone);
    final contactValue = contactPhone ?? userPhone;
    final contactVerified = contactPhone == null && phoneVerified;

    // Verifications drive the right-column ABR facts (entity type, registered
    // address, in-business-since). Distinct from builder_profiles.service_*
    // which is where the user actually works — see VERIFICATION_AUDIT.md.
    final verifs = ref.watch(myVerificationsProvider);
    final abnVerification = verifs.maybeWhen<Verification?>(
      data: (rows) {
        for (final v in rows) {
          if (v.kind == VerificationKind.abn && v.isVerified) return v;
        }
        return null;
      },
      orElse: () => null,
    );
    final abnVerified = abnVerification != null;
    final entityType = abnVerification?.entityType;
    final abrState = abnVerification?.abrState;
    final abrPostcode = abnVerification?.abrPostcode;
    final abnRegisteredAt = abnVerification?.abnRegisteredAt;
    final registeredLocation = _formatRegisteredLocation(abrState, abrPostcode);
    final inBusinessSince = _formatInBusinessSince(abnRegisteredAt);

    void editProfile() => context.push('/profile/edit');

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              JStatBadge(
                value: rating,
                label: 'Rating',
                icon: AppIcons.star,
                iconColor: c.star,
              ),
              Gap(AppSpacing.sm.w),
              JStatBadge(
                value: reviews,
                label: 'Reviews',
                icon: AppIcons.messageText,
                iconColor: c.available,
              ),
              Gap(AppSpacing.sm.w),
              JStatBadge(
                value: jobsPosted,
                label: 'Jobs posted',
                icon: AppIcons.briefcase,
                iconColor: c.action,
              ),
            ],
          ),
          Gap(AppSpacing.md.h),
          JCard(
            title: 'COMPANY DETAILS',
            children: [
              _InfoRow(
                icon: AppIcons.building,
                label: 'Company',
                value: companyName,
              ),
              _InfoRow(
                icon: AppIcons.receipt,
                label: 'ABN',
                value: abn,
                verified: abnVerified,
              ),
              _InfoRow(
                icon: AppIcons.briefcase,
                label: 'Type',
                value: entityType ?? 'Company',
                verified: entityType != null,
              ),
              if (inBusinessSince != null)
                _InfoRow(
                  icon: AppIcons.calendar,
                  label: 'In business since',
                  value: inBusinessSince,
                  verified: true,
                ),
              if (registeredLocation != null)
                _InfoRow(
                  icon: AppIcons.building,
                  label: 'Registered',
                  value: registeredLocation,
                  verified: true,
                ),
              _InfoRow(
                icon: AppIcons.phone,
                label: 'Phone',
                value: contactValue,
                verified: contactVerified,
                onTap: contactValue == null ? editProfile : null,
              ),
              _InfoRow(
                icon: AppIcons.location,
                label: 'Services in',
                value: location,
                onTap: location == null ? editProfile : null,
              ),
              _InfoRow(
                icon: AppIcons.website,
                label: 'Website',
                value: website,
                onTap: website == null
                    ? editProfile
                    : () => _launchWebsite(website),
              ),
            ],
          ),
          Gap(12.h),
          if (p?.id != null)
            VerificationReceipts(
              userId: p!.id,
              isOwner: true,
              showLicenceRow: false,
            ),
        ],
      ),
    );
  }
}

// ── Trade Profile ──────────────────────────────────────────────────────────────

class _TradeProfile extends ConsumerWidget {
  const _TradeProfile({this.profile});

  final TradeProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final p = profile;

    final rating = p?.averageRating?.toStringAsFixed(1) ?? '—';
    final jobsDone = (p?.jobsCompleted ?? 0).toString();
    final yrsExp = p?.yearsExperience != null ? '${p!.yearsExperience}+' : '—';

    final trade = _blank(p?.displayTrade);
    final location = _blank(p?.displayLocation);
    final hasLicence = p?.hasLicence ?? false;
    // Verified flag derives from the new verifications table (the legacy
    // trade_profiles.is_verified column isn't written by the v2.1 wizard,
    // so reading it would leave this banner stuck on "Available for work"
    // even after a successful licence check).
    final verifs = ref.watch(myVerificationsProvider);
    final isVerified = verifs.maybeWhen(
      data: (rows) =>
          rows.any((v) => v.kind == VerificationKind.licence && v.isVerified),
      orElse: () => p?.isVerified ?? false,
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              JStatBadge(
                value: rating,
                label: 'Rating',
                icon: AppIcons.star,
                iconColor: c.star,
              ),
              Gap(AppSpacing.sm.w),
              JStatBadge(
                value: jobsDone,
                label: 'Jobs done',
                icon: AppIcons.successCircle,
                iconColor: c.verified,
              ),
              Gap(AppSpacing.sm.w),
              JStatBadge(
                value: yrsExp,
                label: 'Yrs exp',
                icon: AppIcons.award,
                iconColor: c.action,
              ),
            ],
          ),
          Gap(AppSpacing.md.h),
          // Availability / verification banner
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w,
              vertical: 12.h,
            ),
            decoration: BoxDecoration(
              color: isVerified ? c.verifiedBg : c.surface,
              borderRadius: BorderRadius.circular(AppRadius.card.r),
              border: Border.all(color: isVerified ? c.verified : c.border),
            ),
            child: Row(
              children: [
                Icon(
                  isVerified ? AppIcons.verified : AppIcons.successCircle,
                  size: 18.r,
                  color: isVerified ? c.verified : c.text3,
                ),
                Gap(10.w),
                Text(
                  isVerified ? 'Verified tradie' : 'Available for work',
                  style: tt.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isVerified ? c.verifiedTx : c.text2,
                  ),
                ),
                const Spacer(),
                Text(
                  'Change',
                  style: tt.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w500,
                    color: c.text3,
                    decoration: TextDecoration.underline,
                    decorationColor: c.text3,
                  ),
                ),
              ],
            ),
          ),
          Gap(12.h),
          JCard(
            title: 'TRADE DETAILS',
            children: [
              _InfoRow(icon: AppIcons.licence, label: 'Trade', value: trade),
              _InfoRow(
                icon: AppIcons.document,
                label: 'Licence',
                value: hasLicence ? 'On file' : null,
              ),
              _InfoRow(
                icon: AppIcons.location,
                label: 'Base suburb',
                value: location,
              ),
              _InfoRow(
                icon: AppIcons.budget,
                label: 'Hourly rate',
                value: _formatHourlyRate(p),
              ),
            ],
          ),
          Gap(12.h),
          if (p?.id != null)
            VerificationReceipts(
              userId: p!.id,
              isOwner: true,
              showAbnRow: false,
              showLicenceRow: true,
            ),
        ],
      ),
    );
  }
}

// ── Settings ───────────────────────────────────────────────────────────────────

class _SettingsSection extends ConsumerWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        children: [
          JCard(
            title: 'APPEARANCE',
            children: [
              _ToggleRow(
                icon: isDark ? AppIcons.moon : AppIcons.sun,
                label: 'Dark mode',
                value: isDark,
                onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
              ),
            ],
          ),
          Gap(12.h),
          JCard(
            title: 'ACCOUNT',
            children: [
              _ActionRow(icon: AppIcons.email, label: 'Change email'),
              _ActionRow(icon: AppIcons.lock, label: 'Change password'),
              _ActionRow(icon: AppIcons.notification, label: 'Notifications'),
              _ActionRow(icon: AppIcons.policy, label: 'Privacy settings'),
            ],
          ),
          Gap(12.h),
          JCard(
            title: 'LEGAL',
            children: [
              _ActionRow(
                icon: AppIcons.document,
                label: 'Terms of Service',
                onTap: () => context.push('/legal/terms'),
              ),
              _ActionRow(
                icon: AppIcons.shield,
                label: 'Privacy Policy',
                onTap: () => context.push('/legal/privacy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.verified = false,
  });

  final IconData icon;
  final String label;

  /// Null or blank renders a muted "Not set" — never a fabricated value.
  final String? value;

  /// When set, the row becomes tappable (e.g. website → launchUrl). Only
  /// fires when [value] is non-blank — "Not set" rows aren't actionable.
  final VoidCallback? onTap;

  /// When true, a small green seal-check renders to the right of the value.
  /// Used today to confirm a builder's ABN has been matched against the
  /// Australian Business Register — the full receipt still lives in the
  /// VerificationReceipts panel below, this is just an inline confirmation.
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    final hasValue = value != null && value!.trim().isNotEmpty;
    // Three tap modes:
    //   • value present + onTap set → action on the value (e.g. open website)
    //   • value missing + onTap set → "Add" affordance routing to edit page
    //   • no onTap → static row
    final tappable = onTap != null;
    final isAddCta = !hasValue && tappable;
    final showTick = verified && hasValue;

    final valueColor = isAddCta
        ? c.action
        : hasValue
        ? (tappable ? c.action : c.text1)
        : c.text3;

    final row = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: 12.h,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16.r, color: c.text3),
          Gap(12.w),
          Text(label, style: tt.bodyMedium!.copyWith(color: c.text2)),
          Gap(12.w),
          Expanded(
            child: Text(
              hasValue ? value! : (isAddCta ? 'Add' : 'Not set'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: tt.bodyMedium!.copyWith(
                fontWeight: hasValue
                    ? FontWeight.w600
                    : (isAddCta ? FontWeight.w600 : FontWeight.w400),
                color: valueColor,
              ),
            ),
          ),
          if (showTick) ...[
            Gap(8.w),
            Tooltip(
              message: verified && label == 'Phone'
                  ? 'Phone number verified via SMS'
                  : 'Checked against the Australian Business Register',
              child: Icon(AppIcons.verified, size: 16.r, color: c.verified),
            ),
          ],
          if (isAddCta) ...[
            Gap(6.w),
            Icon(AppIcons.chevronRight, size: 16.r, color: c.action),
          ],
        ],
      ),
    );
    if (!tappable) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// `WA` + `6061` → `WA 6061`. Either or both can be null — return null only
/// when nothing is set so the row hides entirely.
String? _formatRegisteredLocation(String? state, String? postcode) {
  final hasState = state != null && state.trim().isNotEmpty;
  final hasPostcode = postcode != null && postcode.trim().isNotEmpty;
  if (!hasState && !hasPostcode) return null;
  if (hasState && hasPostcode) return '${state.trim()} ${postcode.trim()}';
  return (state ?? postcode)!.trim();
}

/// `2013-08-12` → `Aug 2013`. Returns null for null input so the row hides.
/// Day precision is irrelevant to the human reading "in business since" —
/// month + year is the trust signal.
String? _formatInBusinessSince(DateTime? d) {
  if (d == null) return null;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[d.month - 1]} ${d.year}';
}

/// `93779861687` → `93 779 861 687`. Returns null for null/blank input. Spaces
/// after the leading 2 digits + every following triplet match ABR's display
/// convention and read significantly faster on small screens.
String? _formatAbn(String? raw) {
  if (raw == null) return null;
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 11) return raw; // unexpected — return as-is
  return '${digits.substring(0, 2)} '
      '${digits.substring(2, 5)} '
      '${digits.substring(5, 8)} '
      '${digits.substring(8, 11)}';
}

/// `+639917934774` → `+63 991 793 4774`. Falls back to the raw string if the
/// number isn't long enough to chunk cleanly — we never want to mangle a
/// number the user is reading off a screen to copy-confirm.
String? _formatPhone(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  // Tolerate stored-without-`+` values like the one set by Supabase Auth.
  var s = raw.trim();
  if (!s.startsWith('+')) s = '+$s';
  final digits = s.substring(1).replaceAll(RegExp(r'\D'), '');
  if (digits.length < 8) return s;
  // Heuristic split: 2-digit country code, then 3-3-rest.
  final cc = digits.substring(0, 2);
  final rest = digits.substring(2);
  if (rest.length <= 6) return '+$cc $rest';
  final a = rest.substring(0, 3);
  final b = rest.substring(3, 6);
  final tail = rest.substring(6);
  return '+$cc $a $b $tail';
}

/// Returns null for null/blank strings so [_InfoRow] shows its empty state
/// instead of an empty or fabricated value.
String? _blank(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

/// Launches the builder's website in an in-app browser. Auto-prepends https://
/// if the user saved a bare domain (we don't enforce a scheme at write time).
Future<void> _launchWebsite(String raw) async {
  final url = raw.startsWith('http') ? raw : 'https://$raw';
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  }
}

/// Formats the tradie hourly-rate range for the TRADE DETAILS card.
/// - Visibility off → "Rate on request" (still shows the row).
/// - Both null/zero → null (row hides via _InfoRow's empty state).
/// - Min only → "$X+/hr"; max only → "Up to $X/hr"; both → "$X–Y/hr".
String? _formatHourlyRate(TradeProfile? p) {
  if (p == null) return null;
  if (!p.hourlyRateVisible) return 'Rate on request';
  final min = p.hourlyRateMin;
  final max = p.hourlyRateMax;
  if (min == null && max == null) return null;
  String fmt(double v) => '\$${v.toStringAsFixed(0)}';
  if (min != null && max != null) return '${fmt(min)}–${fmt(max)}/hr';
  if (min != null) return '${fmt(min)}+/hr';
  return 'Up to ${fmt(max!)}/hr';
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? () {},
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w,
          vertical: 14.h,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18.r, color: c.text2),
            Gap(12.w),
            Expanded(
              child: Text(
                label,
                style: tt.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w500,
                  color: c.text1,
                ),
              ),
            ),
            Icon(AppIcons.chevronRight, size: 16.r, color: c.text3),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: 10.h,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18.r, color: c.text2),
          Gap(12.w),
          Expanded(
            child: Text(
              label,
              style: tt.bodyLarge!.copyWith(
                fontWeight: FontWeight.w500,
                color: c.text1,
              ),
            ),
          ),
          JSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
