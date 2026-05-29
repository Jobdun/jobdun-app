import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/design/widgets/field_label.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/j_staggered_list.dart';
import '../../../../core/design/widgets/job_card.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../../core/design/widgets/tradie_card.dart';
import '../../../../core/services/ftue_service.dart';
import '../../../../core/services/profile_analytics.dart';
import '../../../applications/presentation/providers/applications_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/onboarding_completion_sheet.dart';
import '../widgets/profile_completeness_banner.dart';
import '../../../jobs/domain/entities/job.dart';
import '../../../jobs/presentation/providers/jobs_provider.dart';
import '../../../jobs/presentation/pages/job_detail_page.dart';
import '../../../profile/domain/entities/builder_profile.dart';
import '../../../profile/domain/entities/trade_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

part 'home_widgets.dart';
part 'home_map_view.dart';
part 'home_map_widgets.dart';
part 'home_sample_data.dart';

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
      final userId = ref.read(currentUserIdSyncProvider);
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

  // Fires the role sheet ONLY when we're SURE the user has no user_roles row.
  // Three gates:
  //   1. _roleSheetShown — per-instance memo so we never fire twice in the
  //      same HomePage lifetime.
  //   2. AuthState flags — must be authenticated, role must have finished
  //      loading, and the in-memory role must be null. Filters out the
  //      pre-load race that would otherwise prompt users who already picked.
  //   3. Last-chance DB check — even when (2) says role is null, query
  //      user_roles directly before showing. Closes the gap where the JWT
  //      claim is absent (custom_access_token hook not wired in Dashboard)
  //      but a row exists server-side. If the row is there, hydrate the
  //      controller's role from it and DON'T show the sheet.
  //
  // 2026-05-27: gate widened from role-only to role-OR-display_name. SSO and
  // phone signups now route into [OnboardingCompletionSheet], which collects
  // role + name + optional avatar in one flow. The sheet's own skip-step
  // logic decides which steps to render based on what's already populated.
  Future<void> _maybeShowRoleSheet(AuthState auth) async {
    if (_roleSheetShown) return;
    if (!auth.isAuthenticated || !auth.isRoleLoaded) return;

    // Profile-loaded gate: ProfileState doesn't have an isProfileLoaded flag
    // (unlike auth.isRoleLoaded), so we use `profile == null && error == null`
    // as the "load hasn't resolved yet" signal. Without this guard the
    // initState postFrame would see a stale-null profile and false-positive
    // on needsName, opening the sheet for users whose name is actually set.
    // The ref.listen on profile state in build() re-runs this gate once
    // loadProfile resolves.
    final profileState = ref.read(profileControllerProvider);
    if (profileState.profile == null && profileState.error == null) return;

    final hadRowInDb = auth.role != null
        ? false
        : await ref.read(authControllerProvider.notifier).hydrateRoleFromDb();
    if (!mounted) return;

    // After hydration the controller's role is updated if a DB row existed.
    final refreshed = ref.read(authControllerProvider);
    final profile = ref.read(profileControllerProvider).profile;
    final needsRole = refreshed.role == null;
    final needsName = (profile?.displayName ?? '').trim().isEmpty;
    if (!needsRole && !needsName) return;
    if (hadRowInDb && !needsName) return; // role hydrated + name present

    // Latch only when we're actually going to show, so a brief race where
    // both gates returned early doesn't permanently suppress the sheet.
    _roleSheetShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) OnboardingCompletionSheet.show(context);
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
    // Profile load is async + can resolve AFTER the initState postFrame ran
    // the gate. Re-run when profile state changes so a populated display_name
    // suppresses the sheet on the next pass.
    ref.listen<ProfileState>(profileControllerProvider, (_, _) {
      _maybeShowRoleSheet(ref.read(authControllerProvider));
    });

    final c = context.c;
    final authState = ref.watch(authControllerProvider);
    final profileState = ref.watch(profileControllerProvider);
    final jobsState = ref.watch(jobsControllerProvider);
    final appsState = ref.watch(applicationsControllerProvider);

    final isBuilder = authState.role == UserRole.builder;

    final location = isBuilder
        ? profileState.builderProfile?.displayLocation ?? 'Sydney, NSW'
        : profileState.tradeProfile?.displayLocation ?? 'Parramatta, NSW';

    final feedJobs = jobsState.jobs.take(3).toList();
    final hasRealJobs = feedJobs.isNotEmpty;

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
                _viewMode == _ViewMode.list ? AppIcons.map : AppIcons.gridView,
                color: Colors.white, // intentional: white-on-action
                size: 22.r,
              ),
            )
          : null,
      body: _viewMode == _ViewMode.map
          ? _MapView(
              jobs: jobsWithLocation,
              placeLabel: location,
              onJobTap: (j) => context.push(
                '/jobs/${j.id}',
                extra: JobDetailArgs.fromJob(j),
              ),
            )
          : SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(isBuilder: isBuilder, location: location),
                  ),
                  const SliverToBoxAdapter(child: ProfileCompletenessBanner()),
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
                      child: FieldLabel(
                        isBuilder ? 'AVAILABLE TRADIES' : 'JOBS NEARBY',
                      ),
                    ),
                  ),
                  if (isBuilder)
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      sliver: JStaggeredSliverList(
                        itemCount: _tradies.length,
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
                      sliver: JStaggeredSliverList(
                        itemCount: hasRealJobs
                            ? feedJobs.length
                            : _mockJobs.length,
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
