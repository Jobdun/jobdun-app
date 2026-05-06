import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final role = authState.role;
    final isBuilder = role == UserRole.builder;
    final email = authState.email ?? '';
    final firstName = _extractFirstName(email);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(firstName: firstName, role: role)),
            SliverToBoxAdapter(child: Gap(20.h)),
            SliverToBoxAdapter(child: _StatsRow(isBuilder: isBuilder)),
            SliverToBoxAdapter(child: Gap(24.h)),
            SliverToBoxAdapter(child: _PrimaryActionCard(isBuilder: isBuilder)),
            SliverToBoxAdapter(child: Gap(24.h)),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Text(
                  isBuilder ? 'AVAILABLE TRADES' : 'JOBS NEARBY',
                  style: GoogleFonts.barlow(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.12 * 11,
                    color: AppColors.text3,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: Gap(12.h)),
            if (isBuilder)
              SliverList(
                delegate: SliverChildListDelegate(_builderTradieCards()),
              )
            else
              SliverList(
                delegate: SliverChildListDelegate(_tradeJobCards()),
              ),
            SliverToBoxAdapter(child: Gap(16.h)),
          ],
        ),
      ),
    );
  }

  static String _extractFirstName(String email) {
    final local = email.split('@').first;
    final parts = local.replaceAll(RegExp(r'[._\-]'), ' ').split(' ');
    final first = parts.isNotEmpty ? parts.first : local;
    return first.isEmpty ? 'there' : '${first[0].toUpperCase()}${first.substring(1)}';
  }

  List<Widget> _builderTradieCards() {
    return [
      _TradieCard(
        name: 'Marcus Webb',
        trade: 'Electrician',
        suburb: 'Parramatta NSW',
        rating: 4.9,
        jobCount: 142,
        isVerified: true,
        isAvailable: true,
        distanceKm: 3.2,
        initials: 'MW',
      ),
      _TradieCard(
        name: "Sarah O'Brien",
        trade: 'Plumber',
        suburb: 'Bondi NSW',
        rating: 4.7,
        jobCount: 89,
        isVerified: true,
        isAvailable: false,
        distanceKm: 5.1,
        initials: 'SO',
      ),
      _TradieCard(
        name: 'Jake Kowalski',
        trade: 'Carpenter',
        suburb: 'Newtown NSW',
        rating: 4.6,
        jobCount: 67,
        isVerified: false,
        isAvailable: true,
        distanceKm: 7.8,
        initials: 'JK',
      ),
    ];
  }

  List<Widget> _tradeJobCards() {
    return [
      _JobCard(
        title: 'Install 3-phase switchboard at commercial site',
        company: 'Pinnacle Construct',
        suburb: 'Surry Hills NSW',
        rate: '\$85/hr',
        trade: 'Electrician',
        isUrgent: true,
        postedAgo: '2h ago',
      ),
      _JobCard(
        title: 'Frame internal walls for home renovation',
        company: 'BuildRight Pty Ltd',
        suburb: 'Newtown NSW',
        rate: '\$45/hr',
        trade: 'Carpenter',
        isUrgent: false,
        postedAgo: '5h ago',
      ),
      _JobCard(
        title: 'Concrete footings for deck extension',
        company: 'Coast & Country Builds',
        suburb: 'Cronulla NSW',
        rate: '\$75/hr',
        trade: 'Concreter',
        isUrgent: false,
        postedAgo: '1d ago',
      ),
    ];
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.firstName, required this.role});

  final String firstName;
  final UserRole? role;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return Container(
      color: AppColors.card,
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: GoogleFonts.barlow(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.text3,
                  ),
                ),
                Gap(2.h),
                Text(
                  firstName,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.02 * 26,
                    color: AppColors.text1,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (role != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.chip.r),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    role!.label.toUpperCase(),
                    style: GoogleFonts.barlow(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.08 * 10,
                      color: AppColors.text2,
                    ),
                  ),
                ),
              Gap(12.w),
              GestureDetector(
                onTap: () => context.go('/notifications'),
                child: Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.avatar.r),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(Iconsax.notification, size: 20.r, color: AppColors.text2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stats Row ──────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.isBuilder});

  final bool isBuilder;

  @override
  Widget build(BuildContext context) {
    final stats = isBuilder
        ? [('3', 'Active Jobs'), ('12', 'Applicants'), ('2', 'In Progress')]
        : [('5', 'Applied'), ('2', 'Shortlisted'), ('1', 'Accepted')];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: List.generate(stats.length, (i) {
          final stat = stats[i];
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 8.w),
              child: _StatCard(value: stat.$1, label: stat.$2),
            ),
          );
        }),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.barlowCondensed(
              fontSize: 28.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.text1,
            ),
          ),
          Gap(2.h),
          Text(
            label,
            style: GoogleFonts.barlow(
              fontSize: 11.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.text3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Primary Action Card ────────────────────────────────────────────────────────

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({required this.isBuilder});

  final bool isBuilder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GestureDetector(
        onTap: () => context.go(isBuilder ? '/jobs/create' : '/jobs'),
        child: Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: AppColors.foundation,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
          ),
          child: Row(
            children: [
              Container(
                width: 44.r,
                height: 44.r,
                decoration: BoxDecoration(
                  color: AppColors.action,
                  borderRadius: BorderRadius.circular(AppRadius.avatar.r),
                ),
                child: Icon(
                  isBuilder ? Iconsax.add_square : Iconsax.search_normal,
                  size: 22.r,
                  color: Colors.white,
                ),
              ),
              Gap(16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBuilder ? 'Post a new job' : 'Browse open jobs',
                      style: GoogleFonts.barlow(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Gap(2.h),
                    Text(
                      isBuilder
                          ? 'Find skilled trades for your next project'
                          : 'Construction work near you',
                      style: GoogleFonts.barlow(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Iconsax.arrow_right_3, size: 20.r, color: Colors.white.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tradie Card (Builder view) ─────────────────────────────────────────────────

class _TradieCard extends StatelessWidget {
  const _TradieCard({
    required this.name,
    required this.trade,
    required this.suburb,
    required this.rating,
    required this.jobCount,
    required this.isVerified,
    required this.isAvailable,
    required this.distanceKm,
    required this.initials,
  });

  final String name;
  final String trade;
  final String suburb;
  final double rating;
  final int jobCount;
  final bool isVerified;
  final bool isAvailable;
  final double distanceKm;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48.r,
              height: 48.r,
              decoration: BoxDecoration(
                color: AppColors.foundation,
                borderRadius: BorderRadius.circular(AppRadius.avatar.r),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: GoogleFonts.barlow(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.barlow(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text1,
                          ),
                        ),
                      ),
                      if (isAvailable)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: AppColors.verifiedBg,
                            borderRadius: BorderRadius.circular(AppRadius.badge.r),
                          ),
                          child: Text(
                            'Available',
                            style: GoogleFonts.barlow(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.verifiedTx,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Gap(3.h),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.badge.r),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          trade,
                          style: GoogleFonts.barlow(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text2,
                          ),
                        ),
                      ),
                      if (isVerified) ...[
                        Gap(6.w),
                        Icon(Iconsax.verify5, size: 14.r, color: AppColors.verified),
                        Gap(2.w),
                        Text(
                          'Verified',
                          style: GoogleFonts.barlow(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.verified,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Gap(6.h),
                  Row(
                    children: [
                      Icon(Iconsax.star1, size: 12.r, color: const Color(0xFFF59E0B)),
                      Gap(3.w),
                      Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.barlow(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text1,
                        ),
                      ),
                      Gap(3.w),
                      Text(
                        '($jobCount jobs)',
                        style: GoogleFonts.barlow(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.text3,
                        ),
                      ),
                      const Spacer(),
                      Icon(Iconsax.location, size: 12.r, color: AppColors.text3),
                      Gap(2.w),
                      Text(
                        '${distanceKm}km · $suburb',
                        style: GoogleFonts.barlow(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.text3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Job Card (Trade view) ──────────────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.title,
    required this.company,
    required this.suburb,
    required this.rate,
    required this.trade,
    required this.isUrgent,
    required this.postedAgo,
  });

  final String title;
  final String company;
  final String suburb;
  final String rate;
  final String trade;
  final bool isUrgent;
  final String postedAgo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
      child: GestureDetector(
        onTap: () => context.go('/jobs'),
        child: Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            border: Border.all(
              color: isUrgent ? AppColors.urgent : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.barlow(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text1,
                        height: 1.4,
                      ),
                    ),
                  ),
                  Gap(8.w),
                  if (isUrgent)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: AppColors.urgentBg,
                        borderRadius: BorderRadius.circular(AppRadius.badge.r),
                      ),
                      child: Text(
                        'URGENT',
                        style: GoogleFonts.barlow(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.06 * 10,
                          color: AppColors.urgentTx,
                        ),
                      ),
                    ),
                ],
              ),
              Gap(8.h),
              Row(
                children: [
                  Icon(Iconsax.building_3, size: 13.r, color: AppColors.text3),
                  Gap(4.w),
                  Text(
                    company,
                    style: GoogleFonts.barlow(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.text2,
                    ),
                  ),
                  Gap(12.w),
                  Icon(Iconsax.location, size: 13.r, color: AppColors.text3),
                  Gap(4.w),
                  Text(
                    suburb,
                    style: GoogleFonts.barlow(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.text2,
                    ),
                  ),
                ],
              ),
              Gap(10.h),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.badge.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      trade,
                      style: GoogleFonts.barlow(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    rate,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.action,
                    ),
                  ),
                  Gap(12.w),
                  Text(
                    postedAgo,
                    style: GoogleFonts.barlow(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.text3,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
