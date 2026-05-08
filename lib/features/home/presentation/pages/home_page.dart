import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/job_card.dart';
import '../../../../core/design/widgets/tradie_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Sample data — placeholder until Supabase queries are wired
const _kBuilderLocation = 'Sydney, NSW';
const _kTradeLocation = 'Parramatta, NSW';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final authState = ref.watch(authControllerProvider);
    final role = authState.role;
    final isBuilder = role == UserRole.builder;
    final email = authState.email ?? '';
    final firstName = _firstName(email);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                role: role,
                firstName: firstName,
                isBuilder: isBuilder,
              ),
            ),
            SliverToBoxAdapter(child: Gap(20.h)),
            SliverToBoxAdapter(child: _StatsRow(isBuilder: isBuilder)),
            SliverToBoxAdapter(child: Gap(24.h)),
            SliverToBoxAdapter(child: _PrimaryActionCard(isBuilder: isBuilder)),
            SliverToBoxAdapter(child: Gap(24.h)),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
                child: Text(
                  isBuilder ? 'AVAILABLE TRADIES' : 'JOBS NEARBY',
                  style: GoogleFonts.barlow(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.12 * 11,
                    color: c.text3,
                  ),
                ),
              ),
            ),
            if (isBuilder)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                sliver: SliverList.separated(
                  itemCount: _tradies.length,
                  separatorBuilder: (ctx, idx) => Gap(9.h),
                  itemBuilder: (_, i) {
                    final t = _tradies[i];
                    return TradieCard(
                      name: t.name,
                      trade: t.trade,
                      suburb: t.suburb,
                      rating: t.rating,
                      jobCount: t.jobCount,
                      isVerified: t.isVerified,
                      isAvailable: t.isAvailable,
                      distanceKm: t.distanceKm,
                      initials: t.initials,
                      onTap: () {},
                    );
                  },
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                sliver: SliverList.separated(
                  itemCount: _jobs.length,
                  separatorBuilder: (ctx, idx) => Gap(9.h),
                  itemBuilder: (_, i) {
                    final j = _jobs[i];
                    return JobCard(
                      title: j.title,
                      description: j.description,
                      rate: j.rate,
                      startDate: j.startDate,
                      distanceKm: j.distanceKm,
                      isUrgent: j.isUrgent,
                      onTap: () => context.go('/jobs'),
                    );
                  },
                ),
              ),
            SliverToBoxAdapter(child: Gap(24.h)),
          ],
        ),
      ),
    );
  }

  static String _firstName(String email) {
    final local = email.split('@').first;
    final parts = local.replaceAll(RegExp(r'[._\-]'), ' ').split(' ');
    final first = parts.isNotEmpty ? parts.first : local;
    if (first.isEmpty) return 'there';
    return '${first[0].toUpperCase()}${first.substring(1)}';
  }
}

// ── Header — Eyebrow → Display (40sp Condensed 700) → Location (action orange) → NotifBtn

class _Header extends StatelessWidget {
  const _Header({
    required this.role,
    required this.firstName,
    required this.isBuilder,
  });

  final UserRole? role;
  final String firstName;
  final bool isBuilder;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final roleLabel = role != null
        ? '${role!.label.toUpperCase()} · ${firstName.toUpperCase()}'
        : 'JOBDUN';

    return Container(
      color: c.card,
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roleLabel,
                  style: GoogleFonts.barlow(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.12 * 11,
                    color: c.text3,
                  ),
                ),
                Gap(4.h),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFB300),
                      Color(0xFFF97316),
                      Color(0xFFE64A19),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    isBuilder ? 'FIND A TRADIE' : 'JOBS NEARBY',
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 40.sp,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.02 * 40,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
                Gap(4.h),
                Row(
                  children: [
                    Icon(Iconsax.location, size: 12.r, color: c.action),
                    Gap(4.w),
                    Text(
                      isBuilder ? _kBuilderLocation : _kTradeLocation,
                      style: GoogleFonts.barlow(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.02 * 11,
                        color: c.action,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Gap(12.w),
          GestureDetector(
            onTap: () => context.go('/notifications'),
            child: Container(
              width: 34.r,
              height: 34.r,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppRadius.avatar.r),
                border: Border.all(color: c.border),
              ),
              child: Icon(Iconsax.notification, size: 18.r, color: c.text2),
            ),
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
        ? [('3', 'Active jobs'), ('12', 'Applicants'), ('2', 'In progress')]
        : [('5', 'Applied'), ('2', 'Shortlisted'), ('1', 'Accepted')];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: List.generate(stats.length, (i) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 8.w),
              child: _StatCard(value: stats[i].$1, label: stats[i].$2),
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
    final c = context.c;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.barlowCondensed(
              fontSize: 28.sp,
              fontWeight: FontWeight.w700,
              color: c.text1,
              height: 1.0,
            ),
          ),
          Gap(2.h),
          Text(
            label,
            style: GoogleFonts.barlow(
              fontSize: 11.sp,
              fontWeight: FontWeight.w400,
              color: c.text3,
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
    final c = context.c;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GestureDetector(
        onTap: () => context.go(isBuilder ? '/jobs/create' : '/jobs'),
        child: Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
          ),
          child: Row(
            children: [
              Container(
                width: 44.r,
                height: 44.r,
                decoration: BoxDecoration(
                  color: c.action,
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
                        color: c.text1,
                      ),
                    ),
                    Gap(2.h),
                    Text(
                      isBuilder
                          ? 'Find skilled tradies for your next site'
                          : 'Construction work near you',
                      style: GoogleFonts.barlow(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        color: c.text3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Iconsax.arrow_right_3,
                size: 20.r,
                color: c.text3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sample data ────────────────────────────────────────────────────────────────

class _TradieData {
  const _TradieData({
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
}

class _JobData {
  const _JobData({
    required this.title,
    required this.description,
    required this.rate,
    required this.startDate,
    required this.distanceKm,
    required this.isUrgent,
  });

  final String title;
  final String description;
  final String rate;
  final String startDate;
  final double distanceKm;
  final bool isUrgent;
}

const _tradies = [
  _TradieData(
    name: 'Marcus Webb',
    trade: 'Electrician',
    suburb: 'Parramatta',
    rating: 4.9,
    jobCount: 142,
    isVerified: true,
    isAvailable: true,
    distanceKm: 3.2,
    initials: 'MW',
  ),
  _TradieData(
    name: "Sarah O'Brien",
    trade: 'Plumber',
    suburb: 'Bondi',
    rating: 4.7,
    jobCount: 89,
    isVerified: true,
    isAvailable: true,
    distanceKm: 5.1,
    initials: 'SO',
  ),
  _TradieData(
    name: 'Jake Kowalski',
    trade: 'Carpenter',
    suburb: 'Newtown',
    rating: 4.6,
    jobCount: 67,
    isVerified: false,
    isAvailable: false,
    distanceKm: 7.8,
    initials: 'JK',
  ),
];

const _jobs = [
  _JobData(
    title: 'Install 3-phase switchboard at commercial site',
    description:
        'Install a 3-phase switchboard at our commercial fit-out in Surry Hills. Work includes conduit run, panel installation, and termination.',
    rate: r'$85/hr',
    startDate: 'Tomorrow 7am',
    distanceKm: 2.4,
    isUrgent: true,
  ),
  _JobData(
    title: 'Frame internal walls for home renovation',
    description:
        'Steel stud framing approximately 120 LM for a full home renovation in Newtown. Drawings available on site.',
    rate: r'$45/hr',
    startDate: '12 May',
    distanceKm: 4.8,
    isUrgent: false,
  ),
  _JobData(
    title: 'Concrete footings for deck extension',
    description:
        '8 × 300mm dia pad footings, 600mm deep. Reinforcement to be supplied by contractor. All approvals in place.',
    rate: r'$75/hr',
    startDate: '14 May',
    distanceKm: 9.1,
    isUrgent: false,
  ),
];
