import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../app/constants/app_constants.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../core/design/widgets/avatar_block.dart';
import '../../../../core/services/profile_analytics.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/logout_confirm_sheet.dart';
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
            if (profileState.isLoading)
              SliverToBoxAdapter(
                child: LinearProgressIndicator(
                  color: c.action,
                  backgroundColor: c.surface,
                  minHeight: 2,
                ),
              ),
            SliverToBoxAdapter(child: Gap(AppSpacing.md.h)),
            SliverToBoxAdapter(
              child: isBuilder
                  ? _BuilderProfile(profile: profileState.builderProfile)
                  : _TradeProfile(profile: profileState.tradeProfile),
            ),
            SliverToBoxAdapter(child: Gap(AppSpacing.md.h)),
            const SliverToBoxAdapter(child: _ManageSection()),
            SliverToBoxAdapter(child: Gap(AppSpacing.md.h)),
            const SliverToBoxAdapter(child: _SettingsSection()),
            SliverToBoxAdapter(child: Gap(AppSpacing.lg.h)),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: AppButton(
                  label: 'Sign out',
                  variant: AppButtonVariant.secondary,
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
                  ? CircleAvatar(
                      radius: 36.r,
                      backgroundImage: NetworkImage(avatarUrl!),
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
                            Icon(
                              AppIcons.edit,
                              size: AppIconSize.sm.r,
                              color: c.text1,
                            ),
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
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: c.action,
                      borderRadius: BorderRadius.circular(AppRadius.chip.r),
                    ),
                    child: Text(
                      role!.label.toUpperCase(),
                      style: tt.labelSmall!.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.08 * 10,
                        color: Colors.white, // intentional: white-on-action
                      ),
                    ),
                  ),
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

class _BuilderProfile extends StatelessWidget {
  const _BuilderProfile({this.profile});

  final BuilderProfile? profile;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = profile;

    final rating = p?.averageRating?.toStringAsFixed(1) ?? '—';
    final reviews = (p?.ratingCount ?? 0).toString();
    final jobsPosted = (p?.totalJobsPosted ?? 0).toString();

    final companyName = _blank(p?.companyName);
    final abn = _blank(p?.abn);
    final location = _blank(p?.displayLocation);
    final contact = _blank(p?.contactPhone);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatBadge(
                value: rating,
                label: 'Rating',
                icon: AppIcons.rating,
                iconColor: c.star,
              ),
              Gap(AppSpacing.sm.w),
              _StatBadge(
                value: reviews,
                label: 'Reviews',
                icon: AppIcons.chat,
                iconColor: c.available,
              ),
              Gap(AppSpacing.sm.w),
              _StatBadge(
                value: jobsPosted,
                label: 'Jobs posted',
                icon: AppIcons.findJobs.outline,
                iconColor: c.action,
              ),
            ],
          ),
          Gap(AppSpacing.md.h),
          _InfoCard(
            title: 'COMPANY DETAILS',
            children: [
              _InfoRow(
                icon: AppIcons.builder,
                label: 'Company',
                value: companyName,
              ),
              _InfoRow(icon: AppIcons.receipt, label: 'ABN', value: abn),
              _InfoRow(
                icon: AppIcons.findJobs.outline,
                label: 'Type',
                value: 'Company',
              ),
              _InfoRow(
                icon: AppIcons.location,
                label: 'Location',
                value: location,
              ),
              _InfoRow(icon: AppIcons.phone, label: 'Contact', value: contact),
            ],
          ),
          Gap(12.h),
          _InfoCard(
            title: 'VERIFICATION',
            children: [
              _VerificationRow(label: 'ABN verified', isVerified: p != null),
              _VerificationRow(label: 'Email verified', isVerified: true),
              _VerificationRow(label: 'Insurance docs', isVerified: false),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Trade Profile ──────────────────────────────────────────────────────────────

class _TradeProfile extends StatelessWidget {
  const _TradeProfile({this.profile});

  final TradeProfile? profile;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final p = profile;

    final rating = p?.averageRating?.toStringAsFixed(1) ?? '—';
    final jobsDone = (p?.jobsCompleted ?? 0).toString();
    final yrsExp = p?.yearsExperience != null ? '${p!.yearsExperience}+' : '—';

    final trade = _blank(p?.displayTrade);
    final location = _blank(p?.displayLocation);
    final hasLicence = p?.hasLicence ?? false;
    final isVerified = p?.isVerified ?? false;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatBadge(
                value: rating,
                label: 'Rating',
                icon: AppIcons.rating,
                iconColor: c.star,
              ),
              Gap(AppSpacing.sm.w),
              _StatBadge(
                value: jobsDone,
                label: 'Jobs done',
                icon: AppIcons.success,
                iconColor: c.verified,
              ),
              Gap(AppSpacing.sm.w),
              _StatBadge(
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
                  isVerified ? AppIcons.verified : AppIcons.success,
                  size: AppIconSize.md.r,
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
                    color: c.available,
                  ),
                ),
              ],
            ),
          ),
          Gap(12.h),
          _InfoCard(
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
            ],
          ),
          Gap(12.h),
          _InfoCard(
            title: 'VERIFICATION',
            children: [
              _VerificationRow(label: 'Email verified', isVerified: true),
              _VerificationRow(
                label: 'Licence verified',
                isVerified: isVerified,
              ),
              _VerificationRow(label: 'Police check', isVerified: false),
              _VerificationRow(label: 'SWMS uploaded', isVerified: false),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Manage (Trades & Licences, Portfolio) ──────────────────────────────────────

class _ManageSection extends StatelessWidget {
  const _ManageSection();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: _InfoCard(
        title: 'MANAGE',
        children: [
          _ActionRow(
            icon: AppIcons.findJobs.outline,
            label: 'My Trades & Licences',
            onTap: () {
              ProfileAnalytics.sectionTapped(section: 'trades_licences');
              context.push('/profile/trades');
            },
          ),
          Divider(height: 1, color: c.border),
          _ActionRow(
            icon: AppIcons.image,
            label: 'Portfolio',
            onTap: () {
              ProfileAnalytics.sectionTapped(section: 'portfolio');
              context.push('/profile/portfolio');
            },
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
          _InfoCard(
            title: 'APPEARANCE',
            children: [
              _ToggleRow(
                icon: isDark ? AppIcons.darkMode : AppIcons.lightMode,
                label: 'Dark mode',
                value: isDark,
                onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
              ),
            ],
          ),
          Gap(12.h),
          _InfoCard(
            title: 'ACCOUNT',
            children: [
              _ActionRow(icon: AppIcons.email, label: 'Change email'),
              _ActionRow(icon: AppIcons.password, label: 'Change password'),
              _ActionRow(icon: AppIcons.notifications, label: 'Notifications'),
              _ActionRow(icon: AppIcons.verified, label: 'Privacy settings'),
            ],
          ),
          Gap(12.h),
          _InfoCard(
            title: 'LEGAL',
            children: [
              _ActionRow(
                icon: AppIcons.document,
                label: 'Terms of Service',
                onTap: () => context.push('/legal/terms'),
              ),
              _ActionRow(
                icon: AppIcons.insurance,
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

// ── Shared components ──────────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: AppIconSize.md.r, color: iconColor),
            Gap(6.h),
            Text(
              value,
              style: tt.headlineSmall!.copyWith(
                fontSize: 22.sp,
                fontWeight: FontWeight.w900,
                color: c.text1,
              ),
            ),
            Gap(1.h),
            Text(
              label.toUpperCase(),
              style: tt.labelSmall!.copyWith(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: c.text2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md.w,
              14.h,
              AppSpacing.md.w,
              10.h,
            ),
            child: Text(
              title,
              style: tt.labelSmall!.copyWith(
                letterSpacing: 0.12 * 11,
                color: c.text3,
              ),
            ),
          ),
          Divider(height: 1, color: c.border),
          ...children,
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
  });

  final IconData icon;
  final String label;

  /// Null or blank renders a muted "Not set" — never a fabricated value.
  final String? value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    final hasValue = value != null && value!.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: 12.h,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.sm.r, color: c.text3),
          Gap(12.w),
          Text(label, style: tt.bodyMedium!.copyWith(color: c.text2)),
          const Spacer(),
          Flexible(
            child: Text(
              hasValue ? value! : 'Not set',
              style: tt.bodyMedium!.copyWith(
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                color: hasValue ? c.text1 : c.text3,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Returns null for null/blank strings so [_InfoRow] shows its empty state
/// instead of an empty or fabricated value.
String? _blank(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

class _VerificationRow extends StatelessWidget {
  const _VerificationRow({required this.label, required this.isVerified});

  final String label;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: 12.h,
      ),
      child: Row(
        children: [
          Icon(
            isVerified ? AppIcons.verified : AppIcons.closeCircle,
            size: AppIconSize.sm.r,
            color: isVerified ? c.verified : c.text3,
          ),
          Gap(12.w),
          Expanded(
            child: Text(label, style: tt.bodyMedium!.copyWith(color: c.text1)),
          ),
          Text(
            isVerified ? 'Verified' : 'Upload',
            style: tt.bodyMedium!.copyWith(
              fontWeight: FontWeight.w600,
              color: isVerified ? c.verified : c.available,
            ),
          ),
        ],
      ),
    );
  }
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
            Icon(icon, size: AppIconSize.md.r, color: c.text2),
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
            Icon(AppIcons.forward, size: AppIconSize.sm.r, color: c.text3),
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
          Icon(icon, size: AppIconSize.md.r, color: c.text2),
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: c.action,
            activeTrackColor: c.actionBg,
            inactiveThumbColor: c.text3,
            inactiveTrackColor: c.surface,
          ),
        ],
      ),
    );
  }
}
