import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/avatar_block.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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

    final displayName = profileState.profile?.displayName ?? _nameFromEmail(email);
    final initials = _initials(displayName);

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
            const SliverToBoxAdapter(child: _SettingsSection()),
            SliverToBoxAdapter(child: Gap(AppSpacing.lg.h)),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: AppButton(
                  label: 'Sign out',
                  variant: AppButtonVariant.secondary,
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                ),
              ),
            ),
            SliverToBoxAdapter(child: Gap(AppSpacing.xl.h)),
          ],
        ),
      ),
    );
  }

  static String _nameFromEmail(String email) {
    final local = email.split('@').first;
    final parts = local.replaceAll(RegExp(r'[._\-]'), ' ').split(' ');
    final first = parts.isNotEmpty ? parts.first : local;
    if (first.isEmpty) return 'User';
    return '${first[0].toUpperCase()}${first.substring(1)}';
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
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
      padding: EdgeInsets.fromLTRB(20.w, AppSpacing.lg.h, 20.w, AppSpacing.lg.h),
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
                      child: Icon(Iconsax.edit_2, size: 20.r, color: c.text3),
                    ),
                  ],
                ),
                Gap(4.h),
                Text(
                  email,
                  style: tt.bodyMedium!.copyWith(color: c.text3),
                ),
                if (role != null) ...[
                  Gap(AppSpacing.sm.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
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

    final rating = p?.averageRating?.toStringAsFixed(1) ?? '4.8';
    final reviews = p?.ratingCount.toString() ?? '23';
    final jobsPosted = p?.totalJobsPosted.toString() ?? '47';

    final companyName = p?.companyName ?? 'Pinnacle Construct';
    final abn = p?.abn ?? '12 345 678 901';
    final location = p?.displayLocation ?? 'Surry Hills NSW 2010';
    final contact = p?.contactPhone ?? '+61 2 9123 4567';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatBadge(value: rating, label: 'Rating', icon: Iconsax.star, iconColor: c.star),
              Gap(AppSpacing.sm.w),
              _StatBadge(value: reviews, label: 'Reviews', icon: Iconsax.message_text, iconColor: c.available),
              Gap(AppSpacing.sm.w),
              _StatBadge(value: jobsPosted, label: 'Jobs posted', icon: Iconsax.briefcase, iconColor: c.action),
            ],
          ),
          Gap(AppSpacing.md.h),
          _InfoCard(
            title: 'COMPANY DETAILS',
            children: [
              _InfoRow(icon: Iconsax.building_3, label: 'Company', value: companyName),
              _InfoRow(icon: Iconsax.receipt_1, label: 'ABN', value: abn),
              _InfoRow(icon: Iconsax.briefcase, label: 'Type', value: 'Company'),
              _InfoRow(icon: Iconsax.location, label: 'Location', value: location),
              _InfoRow(icon: Iconsax.call, label: 'Contact', value: contact),
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

    final rating = p?.averageRating?.toStringAsFixed(1) ?? '4.9';
    final jobsDone = p?.jobsCompleted.toString() ?? '142';
    final yrsExp = p?.yearsExperience != null ? '${p!.yearsExperience}+' : '5+';

    final trade = p?.displayTrade ?? 'Electrician';
    final location = p?.displayLocation ?? 'Parramatta NSW 2150';
    final isVerified = p?.isVerified ?? false;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatBadge(value: rating, label: 'Rating', icon: Iconsax.star, iconColor: c.star),
              Gap(AppSpacing.sm.w),
              _StatBadge(value: jobsDone, label: 'Jobs done', icon: Iconsax.tick_circle, iconColor: c.verified),
              Gap(AppSpacing.sm.w),
              _StatBadge(value: yrsExp, label: 'Yrs exp', icon: Iconsax.award, iconColor: c.action),
            ],
          ),
          Gap(AppSpacing.md.h),
          // Availability / verification banner
          Container(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isVerified ? c.verifiedBg : c.surface,
              borderRadius: BorderRadius.circular(AppRadius.card.r),
              border: Border.all(color: isVerified ? c.verified : c.border),
            ),
            child: Row(
              children: [
                Icon(
                  isVerified ? Iconsax.verify : Iconsax.tick_circle,
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
              _InfoRow(icon: Iconsax.personalcard, label: 'Trade', value: trade),
              _InfoRow(icon: Iconsax.document_text, label: 'Licence', value: 'EL 123456 (NSW)'),
              _InfoRow(icon: Iconsax.location, label: 'Base suburb', value: location),
              _InfoRow(icon: Iconsax.call, label: 'Phone', value: '+61 4 1234 5678'),
              _InfoRow(icon: Iconsax.calendar_1, label: 'Member since', value: 'May 2026'),
            ],
          ),
          Gap(12.h),
          _InfoCard(
            title: 'VERIFICATION',
            children: [
              _VerificationRow(label: 'Email verified', isVerified: true),
              _VerificationRow(label: 'Licence verified', isVerified: isVerified),
              _VerificationRow(label: 'Police check', isVerified: false),
              _VerificationRow(label: 'SWMS uploaded', isVerified: false),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Settings ───────────────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: _InfoCard(
        title: 'ACCOUNT',
        children: [
          _ActionRow(icon: Iconsax.sms, label: 'Change email'),
          _ActionRow(icon: Iconsax.lock, label: 'Change password'),
          _ActionRow(icon: Iconsax.notification, label: 'Notifications'),
          _ActionRow(icon: Iconsax.shield_tick, label: 'Privacy settings'),
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
            Icon(icon, size: 18.r, color: iconColor),
            Gap(6.h),
            Text(
              value,
              style: tt.headlineSmall!.copyWith(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: c.text1,
              ),
            ),
            Gap(1.h),
            Text(
              label,
              style: tt.labelSmall!.copyWith(
                fontWeight: FontWeight.w400,
                color: c.text3,
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
            padding: EdgeInsets.fromLTRB(AppSpacing.md.w, 14.h, AppSpacing.md.w, 10.h),
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
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: 12.h),
      child: Row(
        children: [
          Icon(icon, size: 16.r, color: c.text3),
          Gap(12.w),
          Text(
            label,
            style: tt.bodyMedium!.copyWith(color: c.text2),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: tt.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: c.text1,
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

class _VerificationRow extends StatelessWidget {
  const _VerificationRow({required this.label, required this.isVerified});

  final String label;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: 12.h),
      child: Row(
        children: [
          Icon(
            isVerified ? Iconsax.verify : Iconsax.close_circle,
            size: 16.r,
            color: isVerified ? c.verified : c.text3,
          ),
          Gap(12.w),
          Expanded(
            child: Text(
              label,
              style: tt.bodyMedium!.copyWith(color: c.text1),
            ),
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
  const _ActionRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: 14.h),
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
            Icon(Iconsax.arrow_right_3, size: 16.r, color: c.text3),
          ],
        ),
      ),
    );
  }
}
