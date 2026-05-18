import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/constants/app_constants.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_gradients.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/design/widgets/job_card.dart';
import '../../../../core/design/widgets/tradie_card.dart';
import '../../../../core/services/ftue_service.dart';
import '../../../../core/services/home_analytics.dart';
import '../../../../core/services/profile_analytics.dart';
import '../../../applications/presentation/providers/applications_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/role_selection_sheet.dart';
import '../widgets/profile_completeness_banner.dart';
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

enum _ViewMode { list, map }

class _HomePageState extends ConsumerState<HomePage> {
  _ViewMode _viewMode = _ViewMode.list;
  bool _roleSheetShown = false;

  // Once-per-device flag — welcome toast fires on the first home visit after
  // email verification, then never again. Backed by FtueService /
  // has_seen_first_home_toast in SharedPreferences. The in-memory guard
  // below stops a second showSnackBar in the same process while the async
  // mark-seen is still in flight.
  bool _welcomeToastInflight = false;

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
        ref
            .read(applicationsControllerProvider.notifier)
            .loadIncomingApplications(userId);
      } else {
        ref
            .read(applicationsControllerProvider.notifier)
            .loadMyApplications(userId);
      }
      // Catches the case where state was already settled before mount.
      _maybeShowRoleSheet(ref.read(authControllerProvider));
      _maybeShowWelcomeToast();
    });
  }

  // Fires the role sheet ONLY after isRoleLoaded is true and role is still
  // null. Without isRoleLoaded the sheet races the JWT load and asks users
  // who already picked at /register a second time.
  void _maybeShowRoleSheet(AuthState auth) {
    if (_roleSheetShown) return;
    if (!auth.isAuthenticated || !auth.isRoleLoaded || auth.role != null)
      return;
    _roleSheetShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) RoleSelectionSheet.show(context);
    });
  }

  // First-home welcome toast — T1 audit spec. Fires once per device the
  // first time the user reaches /home after email verification. Persistent
  // flag lives in SharedPreferences so cold-starts don't replay it.
  // Reactive: also called from the auth-state listener in build() so a
  // late JWT role load still triggers the toast.
  Future<void> _maybeShowWelcomeToast() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated || auth.role == null) return;
    if (_welcomeToastInflight) return;
    _welcomeToastInflight = true;
    try {
      if (await FtueService.hasSeenFirstHomeToast()) return;
      if (!mounted) return;

      final c = context.c;
      final tt = Theme.of(context).textTheme;
      final action = auth.role == UserRole.builder
          ? 'posting jobs'
          : 'applying';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: c.surfaceRaised,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          content: Text(
            "You're in. Finish your profile to start $action.",
            style: tt.bodyMedium!.copyWith(color: c.text1),
          ),
        ),
      );
      await FtueService.markFirstHomeToastSeen();
      ProfileAnalytics.firstToastShown(role: auth.role!.name);
    } catch (_) {
      _welcomeToastInflight = false;
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reactive: if role-load completes after HomePage mounts (typical for the
    // email-verify deep-link flow), this fires the sheet AND the first-home
    // toast then — not earlier. _maybeShowWelcomeToast is idempotent at
    // both the in-process and per-device layers.
    ref.listen<AuthState>(authControllerProvider, (_, next) {
      _maybeShowRoleSheet(next);
      _maybeShowWelcomeToast();
    });

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

    // "Near you" shows the real feed. No pagination/distance scoring yet —
    // that's the deferred T2-backend work; the list is honest as-is.
    final feedJobs = jobsState.jobs;

    final showMapToggle = !isBuilder;
    final jobsWithLocation = jobsState.jobs
        .where((j) => j.hasLocation)
        .toList();

    return Scaffold(
      backgroundColor: c.background,
      floatingActionButton: showMapToggle
          ? FloatingActionButton(
              backgroundColor: c.action,
              onPressed: () => setState(
                () => _viewMode = _viewMode == _ViewMode.list
                    ? _ViewMode.map
                    : _ViewMode.list,
              ),
              child: Icon(
                _viewMode == _ViewMode.list ? Iconsax.map : Iconsax.element_4,
                color: Colors.white, // intentional: white-on-action
                size: AppIconSize.md.r,
              ),
            )
          : null,
      body: _viewMode == _ViewMode.map
          ? _MapView(
              jobs: jobsWithLocation,
              onJobTap: (j) => context.push(
                '/jobs/${j.id}',
                extra: JobDetailArgs.fromJob(j),
              ),
            )
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: () async {
                  HomeAnalytics.refresh();
                  await ref.read(jobsControllerProvider.notifier).refresh();
                },
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
                    const SliverToBoxAdapter(
                      child: ProfileCompletenessBanner(),
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
                    SliverToBoxAdapter(
                      child: _PrimaryActionCard(isBuilder: isBuilder),
                    ),
                    SliverToBoxAdapter(child: Gap(24.h)),
                    if (isBuilder) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
                          child: Text(
                            'AVAILABLE TRADIES',
                            style: tt.labelSmall!.copyWith(
                              letterSpacing: 0.12 * 11,
                              color: c.text3,
                            ),
                          ),
                        ),
                      ),
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
                      ),
                    ] else
                      ..._tradeFeedSlivers(
                        tt,
                        c,
                        feedJobs,
                        jobsState.isLoading,
                      ),
                    SliverToBoxAdapter(child: Gap(24.h)),
                  ],
                ),
              ),
            ),
    );
  }

  // Trade Home feed (Slot 1). "New matches" and "Saved" are honest
  // placeholders — the scoring RPC / saved_jobs table don't exist yet
  // (deferred T2-backend). "Near you" is the real jobs feed.
  List<Widget> _tradeFeedSlivers(
    TextTheme tt,
    JColors c,
    List<Job> feedJobs,
    bool isLoading,
  ) {
    Widget label(String t) => SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
        child: Text(
          t,
          style: tt.labelSmall!.copyWith(
            letterSpacing: 0.12 * 11,
            color: c.text3,
          ),
        ),
      ),
    );

    return [
      label('NEW MATCHES'),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: const _HomeStubCard(
            icon: Iconsax.flash_1,
            title: 'Personalised matches coming soon',
            body:
                'Once matching goes live, best-fit jobs by trade, licence '
                'and distance show here.',
          ),
        ),
      ),
      SliverToBoxAdapter(child: Gap(24.h)),
      label('NEAR YOU'),
      if (feedJobs.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: isLoading
                ? const _HomeStubCard(
                    icon: Iconsax.clock,
                    title: 'Loading jobs near you…',
                    body: '',
                  )
                : _TradeEmptyState(onTap: () => context.go('/profile/edit')),
          ),
        )
      else
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          sliver: SliverList.separated(
            itemCount: feedJobs.length,
            separatorBuilder: (_, _) => Gap(9.h),
            itemBuilder: (_, i) {
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
                onTap: () {
                  HomeAnalytics.cardTapped(jobId: j.id);
                  context.push(
                    '/jobs/${j.id}',
                    extra: JobDetailArgs.fromJob(j),
                  );
                },
              );
            },
          ),
        ),
      SliverToBoxAdapter(child: Gap(24.h)),
      label('SAVED'),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: const _HomeStubCard(
            icon: Iconsax.archive_book,
            title: 'No saved jobs yet',
            body: 'Saving jobs to revisit later arrives in the next update.',
          ),
        ),
      ),
    ];
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
                      color: Colors
                          .white, // intentional: ShaderMask requires white for gradient
                    ),
                  ),
                ),
                Gap(4.h),
                Row(
                  children: [
                    Icon(
                      Iconsax.location,
                      size: AppIconSize.xs.r,
                      color: c.action,
                    ),
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
          Semantics(
            label: 'Notifications',
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Container(
                constraints: BoxConstraints(
                  minWidth: AppTouchTarget.min,
                  minHeight: AppTouchTarget.min,
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 34.r,
                  height: 34.r,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppRadius.avatar.r),
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(
                    Iconsax.notification,
                    size: AppIconSize.md.r,
                    color: c.text2,
                  ),
                ),
              ),
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
        (
          shortlistedCount > 0 ? shortlistedCount.toString() : '—',
          'Shortlisted',
        ),
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
        onTap: () =>
            isBuilder ? context.push('/jobs/create') : context.go('/jobs'),
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
                  size: AppIconSize.md.r,
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
              Icon(
                Iconsax.arrow_right_3,
                size: AppIconSize.md.r,
                color: c.text3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Map View ──────────────────────────────────────────────────────────────────

class _MapView extends StatefulWidget {
  const _MapView({required this.jobs, required this.onJobTap});

  final List<Job> jobs;
  final ValueChanged<Job> onJobTap;

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  static const _sydney = LatLng(-33.8688, 151.2093);

  GoogleMapController? _controller;

  Set<Marker> _buildMarkers() {
    return {
      for (final job in widget.jobs)
        if (job.latitude != null && job.longitude != null)
          Marker(
            markerId: MarkerId(job.id),
            position: LatLng(job.latitude!, job.longitude!),
            infoWindow: InfoWindow(
              title: job.title,
              snippet: job.displayBudget,
              onTap: () => widget.onJobTap(job),
            ),
          ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(target: _sydney, zoom: 11),
      markers: _buildMarkers(),
      onMapCreated: (c) => _controller = c,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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

class _HomeStubCard extends StatelessWidget {
  const _HomeStubCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppIconSize.lg.r, color: c.text3),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.bodyMedium!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  Gap(4.h),
                  Text(body, style: tt.bodySmall!.copyWith(color: c.text3)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeEmptyState extends StatelessWidget {
  const _TradeEmptyState({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Icon(Iconsax.location, size: AppIconSize.xxl.r, color: c.text3),
          Gap(12.h),
          Text(
            'Add your trade + licence to see jobs near you',
            textAlign: TextAlign.center,
            style: tt.bodyMedium!.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w600,
            ),
          ),
          Gap(16.h),
          Semantics(
            button: true,
            label: 'Complete profile',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                constraints: BoxConstraints(minHeight: AppTouchTarget.min),
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
                decoration: BoxDecoration(
                  color: c.action,
                  borderRadius: BorderRadius.circular(AppRadius.btn.r),
                ),
                child: Text(
                  'COMPLETE PROFILE',
                  style: tt.labelLarge!.copyWith(color: c.onAction),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
