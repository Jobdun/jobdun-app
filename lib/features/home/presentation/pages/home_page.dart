import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/preview_theme.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/design/widgets/j_staggered_list.dart';
import '../../../../core/design/widgets/j_switch.dart';
import '../../../../core/design/widgets/j_top_bar.dart';
import '../../../../core/design/widgets/job_card.dart';
import '../../../../core/services/ftue_service.dart';
import '../../../../core/services/profile_analytics.dart';
import '../../../applications/presentation/providers/applications_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/onboarding_completion_sheet.dart';
import '../../../auth/presentation/widgets/onboarding_gate.dart';
import '../widgets/profile_completeness_banner.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../jobs/domain/entities/job.dart';
import '../../../jobs/presentation/providers/jobs_provider.dart';
import '../../../jobs/presentation/pages/job_detail_page.dart';
import '../../../jobs/presentation/pages/job_map_data.dart';
import '../../../profile/domain/entities/builder_profile.dart';
import '../../../profile/domain/entities/trade_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../discovery/presentation/providers/discovery_provider.dart';
import '../../../discovery/presentation/widgets/trade_map_preview.dart';

part 'home_widgets.dart';
part 'home_builder_bento.dart';
part 'home_tradie_availability.dart';
part 'home_map_view.dart';
part 'home_map_widgets.dart';
part 'home_map_overlays.dart';
part 'jobs_map_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, this.fixedPreview = false});

  /// Debug A/B mode. When true this is a faithful copy of the live home page
  /// rendered through [PreviewTheme.fixed] (the accessibility-corrected token
  /// set) with text scaling clamped, a back-arrow AppBar, and the one-shot
  /// role-sheet / welcome-toast side effects suppressed. Reached via the
  /// "Home preview (fixed tokens)" link in the profile page's Developer tools
  /// card (kDebugMode). Nothing about the real /home changes — this just
  /// re-renders the same widget under a different theme.
  final bool fixedPreview;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _roleSheetShown = false;
  bool _roleCheckInflight = false;

  // A/B preview only — which corrected theme the copy renders under. Toggled
  // by the sun/moon action in the preview AppBar. Ignored on the live page.
  Brightness _previewBrightness = Brightness.dark;

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
      // Skipped in the A/B copy so the role sheet / welcome toast don't re-fire.
      if (!widget.fixedPreview) {
        _maybeShowRoleSheet(ref.read(authControllerProvider));
        _maybeShowWelcomeToast();
      }
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
    if (_roleSheetShown || _roleCheckInflight) return;
    if (!auth.isAuthenticated || !auth.isRoleLoaded) return;

    // Profile-loaded gate: ProfileState doesn't have an isProfileLoaded flag
    // (unlike auth.isRoleLoaded), so we use `profile == null && error == null`
    // as the "load hasn't resolved yet" signal. Without this guard the
    // initState postFrame would see a stale-null profile and false-positive
    // on needsName, opening the sheet for users whose name is actually set.
    // The ref.listen on profile state in build() re-runs this gate once
    // loadProfile resolves.
    // Only decide on a SUCCESSFULLY loaded profile. A null profile means the
    // load is still in flight OR it FAILED (offline / transient error) — neither
    // is proof the user lacks a name. Evaluating the gate on a failed load showed
    // the non-dismissible "WELCOME TO JOBDUN" sheet over fully-onboarded users.
    // The profile `ref.listen` in build() re-runs this once the load succeeds.
    if (ref.read(profileControllerProvider).profile == null) return;

    _roleCheckInflight = true;
    try {
      final hadRowInDb = auth.role != null
          ? false
          : await ref.read(authControllerProvider.notifier).hydrateRoleFromDb();
      if (!mounted) return;

      // After hydration the controller's role is updated if a DB row existed.
      final refreshed = ref.read(authControllerProvider);
      final profile = ref.read(profileControllerProvider).profile;
      final needsName = (profile?.displayName ?? '').trim().isEmpty;
      final shouldShow = OnboardingGate.needsCompletion(
        hasProfile: profile != null,
        hasRole: refreshed.role != null,
        displayName: profile?.displayName,
      );
      if (!shouldShow) return;
      if (hadRowInDb && !needsName) return; // role hydrated + name present

      // Latch only when we're actually going to show, so a brief race where
      // both gates returned early doesn't permanently suppress the sheet.
      _roleSheetShown = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) OnboardingCompletionSheet.show(context);
      });
    } finally {
      if (mounted) {
        _roleCheckInflight = false;
      }
    }
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
    // both the in-process and per-device layers. Suppressed in the A/B copy.
    if (!widget.fixedPreview) {
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
    }

    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final authState = ref.watch(authControllerProvider);
    final profileState = ref.watch(profileControllerProvider);
    final jobsState = ref.watch(jobsControllerProvider);
    final appsState = ref.watch(applicationsControllerProvider);

    final isBuilder = authState.role == UserRole.builder;

    final feedJobs = jobsState.jobs.take(3).toList();
    final hasRealJobs = feedJobs.isNotEmpty;

    // Tradies get a "VIEW MAP" FAB → the full-screen jobs map route.
    final showMapToggle = !isBuilder;

    final isLightPreview = _previewBrightness == Brightness.light;

    final scaffold = Scaffold(
      // In preview, let the scaffold inherit the toggled theme's background so
      // light mode shows its own (near-white) ground instead of the dark one.
      backgroundColor: widget.fixedPreview ? null : c.background,
      appBar: widget.fixedPreview
          ? AppBar(
              title: Text(
                isLightPreview ? 'HOME · FIXED (LIGHT)' : 'HOME · FIXED (DARK)',
              ),
              actions: [
                IconButton(
                  tooltip: isLightPreview
                      ? 'Switch to dark'
                      : 'Switch to light',
                  icon: Icon(isLightPreview ? AppIcons.moon : AppIcons.sun),
                  onPressed: () => setState(
                    () => _previewBrightness = isLightPreview
                        ? Brightness.dark
                        : Brightness.light,
                  ),
                ),
              ],
            )
          : null,
      // Tradies open the jobs map full-screen over the shell (its own back
      // button) via /jobs/map — builders use the discovery map instead.
      floatingActionButton: showMapToggle
          ? FloatingActionButton(
              backgroundColor: c.action,
              onPressed: () => context.push('/jobs/map'),
              child: Icon(
                AppIcons.map,
                color:
                    c.background, // dark-on-orange — 6.37:1 (was white, 2.80:1)
                size: AppIconSize.nav.r,
              ),
            )
          : null,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // LinkedIn-style floating utility bar: scrolls away on
            // scroll-down, snaps back on scroll-up. Avatar → profile,
            // search → the jobs list (which owns search), bell →
            // notifications. `primary` is false in the debug A/B copy so
            // it doesn't double the status-bar inset under the debug AppBar.
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: false,
              primary: !widget.fixedPreview,
              automaticallyImplyLeading: false,
              backgroundColor: c.card,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              titleSpacing: 0,
              toolbarHeight: 64.h,
              title: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 8.h),
                child: JTopBar(
                  displayName:
                      (profileState.profile?.displayName ?? '').trim().isEmpty
                      ? 'there'
                      : profileState.profile!.displayName!.trim(),
                  initials: _initials(profileState.profile?.displayName),
                  roleLabel: isBuilder ? 'BUILDER' : 'TRADIE',
                  avatarUrl: profileState.profile?.avatarUrl,
                  onAvatarTap: () => context.go('/profile'),
                  onNotificationsTap: () => context.push('/notifications'),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: ProfileCompletenessBanner()),
            SliverToBoxAdapter(child: Gap(20.h)),
            // Builders get the bento-grid home (direction #02): post-job
            // hero + live stat tiles + tradies-nearby + quick actions.
            if (isBuilder) const SliverToBoxAdapter(child: _BuilderBentoGrid()),
            // Tradie home (direction E): availability bar spine + stats +
            // a list-primary "jobs near you" feed. The map is one tap away
            // via the list/map toggle FAB (showMapToggle).
            if (!isBuilder) ...[
              const SliverToBoxAdapter(child: _TradieAvailabilityBar()),
              SliverToBoxAdapter(
                child: _StatsRow(
                  isBuilder: false,
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
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
                  child: Text(
                    'JOBS NEAR YOU',
                    style: tt.titleLarge!.copyWith(color: c.text1),
                  ),
                ),
              ),
              if (hasRealJobs)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  sliver: JStaggeredSliverList(
                    itemCount: feedJobs.length,
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
                        onTap: () => context.push(
                          '/jobs/${j.id}',
                          extra: JobDetailArgs.fromJob(j),
                        ),
                      );
                    },
                  ),
                )
              else
                const SliverToBoxAdapter(child: _HomeJobsEmpty()),
            ],
            // Clear the map-toggle FAB so the last job card (and its
            // distance line) never scrolls underneath it. Only reserves
            // the extra space when the FAB is actually shown.
            SliverToBoxAdapter(child: Gap(showMapToggle ? 96.h : 24.h)),
          ],
        ),
      ),
    );

    // Live page renders as-is; the A/B copy re-renders the same scaffold under
    // the corrected token theme (dark or light, per the toggle) with text
    // scaling clamped (S0/S1/S2/S3/S5).
    if (!widget.fixedPreview) return scaffold;
    return Theme(
      // Dark path = the proposed NEW type scale on real home content
      // (designV2). Spacing here still uses the global AppSpacing (old) — only
      // /design-preview shows the new 12/16/24 rhythm. Light stays fixedLight
      // (the live app is dark-only; the toggle is for inspection).
      data: isLightPreview
          ? PreviewTheme.fixedLight()
          : PreviewTheme.designV2Dark(),
      child: MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.9,
        maxScaleFactor: 1.3,
        child: scaffold,
      ),
    );
  }

  // First letters of the first two name words, e.g. "Ken Garcia" → "KG".
  // Falls back to a single brand letter for not-yet-named accounts (the
  // onboarding sheet collects the name, so this is rarely shown).
  static String _initials(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'J';
    var out = '';
    for (final p in parts) {
      if (out.length < 2) out += p[0];
    }
    return out.toUpperCase();
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
