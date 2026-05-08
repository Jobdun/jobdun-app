import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/avatar_block.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final authState = ref.watch(authControllerProvider);
    final role = authState.role;
    final isBuilder = role == UserRole.builder;
    final email = authState.email ?? '';
    final initials = _initials(email);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _ProfileHeader(initials: initials, email: email, role: role),
            ),
            SliverToBoxAdapter(child: Gap(16.h)),
            SliverToBoxAdapter(
              child: isBuilder
                  ? const _BuilderProfile()
                  : const _TradeProfile(),
            ),
            SliverToBoxAdapter(child: Gap(16.h)),
            SliverToBoxAdapter(child: const _SettingsSection()),
            SliverToBoxAdapter(child: Gap(24.h)),
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
            SliverToBoxAdapter(child: Gap(32.h)),
          ],
        ),
      ),
    );
  }

  static String _initials(String email) {
    final local = email.split('@').first;
    final parts = local.replaceAll(RegExp(r'[._\-]'), ' ').split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return local.isNotEmpty ? local[0].toUpperCase() : '?';
  }
}

// ── Profile Header ─────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.initials,
    required this.email,
    required this.role,
  });

  final String initials;
  final String email;
  final UserRole? role;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Container(
      color: c.card,
      padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 24.h),
      child: Row(
        children: [
          AvatarBlock(initials: initials, size: 72),
          Gap(16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        email.split('@').first,
                        style: GoogleFonts.openSans(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: c.text1,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: Icon(Iconsax.edit_2, size: 20.r, color: c.text3),
                    ),
                  ],
                ),
                Gap(4.h),
                Text(
                  email,
                  style: GoogleFonts.openSans(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: c.text3,
                  ),
                ),
                if (role != null) ...[
                  Gap(8.h),
                  // Orange badge — high-contrast on both light and dark backgrounds
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: c.action,
                      borderRadius: BorderRadius.circular(AppRadius.chip.r),
                    ),
                    child: Text(
                      role!.label.toUpperCase(),
                      style: GoogleFonts.openSans(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.08 * 10,
                        color: Colors.white,
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
  const _BuilderProfile();

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatBadge(
                value: '4.8',
                label: 'Rating',
                icon: Iconsax.star,
                iconColor: c.star,
              ),
              Gap(8.w),
              _StatBadge(
                value: '23',
                label: 'Reviews',
                icon: Iconsax.message_text,
                iconColor: c.available,
              ),
              Gap(8.w),
              _StatBadge(
                value: '47',
                label: 'Jobs posted',
                icon: Iconsax.briefcase,
                iconColor: c.action,
              ),
            ],
          ),
          Gap(16.h),
          _InfoCard(
            title: 'COMPANY DETAILS',
            children: [
              _InfoRow(icon: Iconsax.building_3, label: 'Company', value: 'Pinnacle Construct'),
              _InfoRow(icon: Iconsax.receipt_1, label: 'ABN', value: '12 345 678 901'),
              _InfoRow(icon: Iconsax.briefcase, label: 'Type', value: 'Company'),
              _InfoRow(icon: Iconsax.location, label: 'Location', value: 'Surry Hills NSW 2010'),
              _InfoRow(icon: Iconsax.call, label: 'Contact', value: '+61 2 9123 4567'),
            ],
          ),
          Gap(12.h),
          _InfoCard(
            title: 'VERIFICATION',
            children: [
              _VerificationRow(label: 'ABN verified', isVerified: true),
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
  const _TradeProfile();

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatBadge(
                value: '4.9',
                label: 'Rating',
                icon: Iconsax.star,
                iconColor: c.star,
              ),
              Gap(8.w),
              _StatBadge(
                value: '142',
                label: 'Jobs done',
                icon: Iconsax.tick_circle,
                iconColor: c.verified,
              ),
              Gap(8.w),
              _StatBadge(
                value: '5+',
                label: 'Yrs exp',
                icon: Iconsax.award,
                iconColor: c.action,
              ),
            ],
          ),
          Gap(16.h),
          // Availability banner
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: c.verifiedBg,
              borderRadius: BorderRadius.circular(AppRadius.card.r),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Icon(Iconsax.tick_circle, size: 18.r, color: c.verified),
                Gap(10.w),
                Text(
                  'Available for work',
                  style: GoogleFonts.openSans(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: c.verifiedTx,
                  ),
                ),
                const Spacer(),
                Text(
                  'Change',
                  style: GoogleFonts.openSans(
                    fontSize: 13.sp,
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
              _InfoRow(icon: Iconsax.personalcard, label: 'Trade', value: 'Electrician'),
              _InfoRow(icon: Iconsax.document_text, label: 'Licence', value: 'EL 123456 (NSW)'),
              _InfoRow(icon: Iconsax.location, label: 'Base suburb', value: 'Parramatta NSW 2150'),
              _InfoRow(icon: Iconsax.call, label: 'Phone', value: '+61 4 1234 5678'),
              _InfoRow(icon: Iconsax.calendar_1, label: 'Member since', value: 'May 2026'),
            ],
          ),
          Gap(12.h),
          _InfoCard(
            title: 'VERIFICATION',
            children: [
              _VerificationRow(label: 'Email verified', isVerified: true),
              _VerificationRow(label: 'Licence verified', isVerified: true),
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
              style: GoogleFonts.oswald(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: c.text1,
              ),
            ),
            Gap(1.h),
            Text(
              label,
              style: GoogleFonts.openSans(
                fontSize: 10.sp,
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
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
            child: Text(
              title,
              style: GoogleFonts.openSans(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
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
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Icon(icon, size: 16.r, color: c.text3),
          Gap(12.w),
          Text(
            label,
            style: GoogleFonts.openSans(
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: c.text2,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.openSans(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: c.text1,
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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
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
              style: GoogleFonts.openSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
                color: c.text1,
              ),
            ),
          ),
          Text(
            isVerified ? 'Verified' : 'Upload',
            style: GoogleFonts.openSans(
              fontSize: 13.sp,
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, size: 18.r, color: c.text2),
            Gap(12.w),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.openSans(
                  fontSize: 14.sp,
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
