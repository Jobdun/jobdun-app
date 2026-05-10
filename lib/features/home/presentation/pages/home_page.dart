import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_gradients.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/design/widgets/job_card.dart';
import '../../../../core/design/widgets/tradie_card.dart';
import '../../../applications/presentation/providers/applications_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../jobs/domain/entities/job.dart';
import '../../../jobs/presentation/providers/jobs_provider.dart';
import '../../../jobs/presentation/pages/job_detail_page.dart';
import '../../../profile/domain/entities/builder_profile.dart';
import '../../../profile/domain/entities/trade_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userId = SupabaseConfig.isInitialized
          ? SupabaseConfig.client.auth.currentUser?.id
          : null;
      if (userId == null) return;
      ref.read(profileControllerProvider.notifier).loadProfile();
      ref.read(jobsControllerProvider.notifier).loadFeed();
      final role = ref.read(authControllerProvider).role;
      if (role == UserRole.builder) {
        ref.read(applicationsControllerProvider.notifier).loadIncomingApplications(userId);
      } else {
        ref.read(applicationsControllerProvider.notifier).loadMyApplications(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final authState = ref.watch(authControllerProvider);
    final profileState = ref.watch(profileControllerProvider);
    final jobsState = ref.watch(jobsControllerProvider);
    final appsState = ref.watch(applicationsControllerProvider);

    final role = authState.role;
    final isBuilder = role == UserRole.builder;
    final email = authState.email ?? '';
    final displayName = profileState.profile?.displayName ?? _firstName(email);

    final location = isBuilder
        ? profileState.builderProfile?.displayLocation ?? 'Sydney, NSW'
        : profileState.tradeProfile?.displayLocation ?? 'Parramatta, NSW';

    final feedJobs = jobsState.jobs.take(3).toList();
    final hasRealJobs = feedJobs.isNotEmpty;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                role: role,
                displayName: displayName,
                isBuilder: isBuilder,
                location: location,
              ),
            ),
            SliverToBoxAdapter(child: Gap(20.h)),
            SliverToBoxAdapter(
              child: _StatsRow(
                isBuilder: isBuilder,
                builderProfile: profileState.builderProfile,
                tradeProfile: profileState.tradeProfile,
                pendingCount: appsState.pendingIncomingCount,
                myAppsCount: appsState.myApplications.length,
                shortlistedCount: appsState.myApplications
                    .where((a) => a.status.name == 'shortlisted')
                    .length,
              ),
            ),
            SliverToBoxAdapter(child: Gap(24.h)),
            SliverToBoxAdapter(child: _PrimaryActionCard(isBuilder: isBuilder)),
            SliverToBoxAdapter(child: Gap(24.h)),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
                child: Text(
                  isBuilder ? 'AVAILABLE TRADIES' : 'JOBS NEARBY',
                  style: tt.labelSmall!.copyWith(
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
                  itemCount: hasRealJobs ? feedJobs.length : _mockJobs.length,
                  separatorBuilder: (ctx, idx) => Gap(9.h),
                  itemBuilder: (_, i) {
                    if (hasRealJobs) {
                      final j = feedJobs[i];
                      return JobCard(
                        title: j.title,
                        description: j.description,
                        rate: j.displayBudget,
                        startDate: j.startDate != null
                            ? _fmtDate(j.startDate!)
                            : j.displayLocation,
                        distanceKm: 0.0,
                        isUrgent: j.urgency == JobUrgency.urgent,
                        onTap: () => context.push(
                          '/jobs/${j.id}',
                          extra: JobDetailArgs.fromJob(j),
                        ),
                      );
                    }
                    final j = _mockJobs[i];
                    return JobCard(
                      title: j.title,
                      description: j.description,
                      rate: j.rate,
                      startDate: j.startDate,
                      distanceKm: j.distanceKm,
                      isUrgent: j.isUrgent,
                      onTap: () => context.push(
                        '/jobs/mock-home-$i',
                        extra: JobDetailArgs(
                          title: j.title,
                          description: j.description,
                          rate: j.rate,
                          startDate: j.startDate,
                          distanceKm: j.distanceKm,
                          isUrgent: j.isUrgent,
                        ),
                      ),
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

  static String _fmtDate(DateTime d) {
    final now = DateTime.now();
    final diff = d.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return '${d.day} ${_months[d.month - 1]}';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.role,
    required this.displayName,
    required this.isBuilder,
    required this.location,
  });

  final UserRole? role;
  final String displayName;
  final bool isBuilder;
  final String location;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final roleLabel = role != null
        ? '${role!.label.toUpperCase()} · ${displayName.toUpperCase()}'
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
                  style: tt.labelSmall!.copyWith(
                    letterSpacing: 0.12 * 11,
                    color: c.text3,
                  ),
                ),
                Gap(4.h),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppGradients.brandFlame.createShader(bounds),
                  child: Text(
                    isBuilder ? 'FIND A TRADIE' : 'JOBS NEARBY',
                    style: tt.headlineSmall!.copyWith(
                      fontSize: 40.sp,
                      letterSpacing: 0.02 * 40,
                      height: 1.0,
                      color: Colors.white, // intentional: ShaderMask requires white for gradient
                    ),
                  ),
                ),
                Gap(4.h),
                Row(
                  children: [
                    Icon(Iconsax.location, size: 12.r, color: c.action),
                    Gap(4.w),
                    Text(
                      location,
                      style: tt.bodySmall!.copyWith(
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
            onTap: () {},
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
  const _StatsRow({
    required this.isBuilder,
    required this.pendingCount,
    required this.myAppsCount,
    required this.shortlistedCount,
    this.builderProfile,
    this.tradeProfile,
  });

  final bool isBuilder;
  final BuilderProfile? builderProfile;
  final TradeProfile? tradeProfile;
  final int pendingCount;
  final int myAppsCount;
  final int shortlistedCount;

  @override
  Widget build(BuildContext context) {
    final List<(String, String)> stats;

    if (isBuilder) {
      final active = builderProfile?.activeJobsCount.toString() ?? '—';
      final total = builderProfile?.totalJobsPosted.toString() ?? '—';
      stats = [
        (active, 'Active jobs'),
        (pendingCount > 0 ? pendingCount.toString() : '—', 'Applicants'),
        (total, 'Jobs posted'),
      ];
    } else {
      final done = tradeProfile?.jobsCompleted.toString() ?? '—';
      stats = [
        (myAppsCount > 0 ? myAppsCount.toString() : '—', 'Applied'),
        (shortlistedCount > 0 ? shortlistedCount.toString() : '—', 'Shortlisted'),
        (done, 'Jobs done'),
      ];
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: List.generate(stats.length, (i) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : AppSpacing.sm.w),
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
    final tt = Theme.of(context).textTheme;

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
            style: tt.headlineSmall!.copyWith(
              fontSize: 28.sp,
              color: c.text1,
              height: 1.0,
            ),
          ),
          Gap(2.h),
          Text(
            label,
            style: tt.bodySmall!.copyWith(
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
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GestureDetector(
        onTap: () => isBuilder ? context.push('/jobs/create') : context.go('/jobs'),
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
                  color: Colors.white, // intentional: white-on-action
                ),
              ),
              Gap(AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBuilder ? 'Post a new job' : 'Browse open jobs',
                      style: tt.titleLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.text1,
                      ),
                    ),
                    Gap(2.h),
                    Text(
                      isBuilder
                          ? 'Find skilled tradies for your next site'
                          : 'Construction work near you',
                      style: tt.bodyMedium!.copyWith(color: c.text3),
                    ),
                  ],
                ),
              ),
              Icon(Iconsax.arrow_right_3, size: 20.r, color: c.text3),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sample / fallback data ─────────────────────────────────────────────────────

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

class _MockJob {
  const _MockJob({
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
    name: 'Marcus Webb', trade: 'Electrician', suburb: 'Parramatta',
    rating: 4.9, jobCount: 142, isVerified: true, isAvailable: true,
    distanceKm: 3.2, initials: 'MW',
  ),
  _TradieData(
    name: "Sarah O'Brien", trade: 'Plumber', suburb: 'Bondi',
    rating: 4.7, jobCount: 89, isVerified: true, isAvailable: true,
    distanceKm: 5.1, initials: 'SO',
  ),
  _TradieData(
    name: 'Jake Kowalski', trade: 'Carpenter', suburb: 'Newtown',
    rating: 4.6, jobCount: 67, isVerified: false, isAvailable: false,
    distanceKm: 7.8, initials: 'JK',
  ),
];

const _mockJobs = [
  _MockJob(
    title: 'Install 3-phase switchboard at commercial site',
    description: 'Install a 3-phase switchboard at our commercial fit-out in Surry Hills. Conduit run, panel installation, and termination.',
    rate: r'$85/hr', startDate: 'Tomorrow', distanceKm: 2.4, isUrgent: true,
  ),
  _MockJob(
    title: 'Frame internal walls for home renovation',
    description: 'Steel stud framing approximately 120 LM for a full home renovation in Newtown. Drawings available on site.',
    rate: r'$45/hr', startDate: '12 May', distanceKm: 4.8, isUrgent: false,
  ),
  _MockJob(
    title: 'Concrete footings for deck extension',
    description: '8 × 300mm dia pad footings, 600mm deep. Reinforcement to be supplied by contractor.',
    rate: r'$75/hr', startDate: '14 May', distanceKm: 9.1, isUrgent: false,
  ),
];
