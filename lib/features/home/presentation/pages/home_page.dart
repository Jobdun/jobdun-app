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

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.isBuilder, required this.location});

  final bool isBuilder;
  final String location;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

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
                PageHeader(
                  // Same `tab` size (24sp Oswald w600) as Jobs / Applications
                  // / Messages so the four bottom-nav landings render with
                  // identical chrome. The previous `hero` (32sp) was a
                  // landing-page emphasis the bottom nav already provides,
                  // and made the title visibly inconsistent when swiping
                  // between tabs.
                  title: isBuilder ? 'Find a tradie' : 'Jobs nearby',
                ),
                Gap(4.h),
                Row(
                  children: [
                    Icon(AppIcons.location, size: 12.r, color: c.text2),
                    Gap(4.w),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall!.copyWith(
                          letterSpacing: 0.02 * 11,
                          color: c.text2,
                        ),
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
              child: Icon(AppIcons.notification, size: 18.r, color: c.text2),
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
                  isBuilder ? AppIcons.addSquare : AppIcons.search,
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
              Icon(AppIcons.chevronRight, size: 20.r, color: c.text3),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Map View ──────────────────────────────────────────────────────────────────

// Selectable basemap. All four sources are free + key-less and properly
// attributed by RichAttributionWidget below. Add a new style by extending this
// enum — the picker sheet, persistence, and tile layer pick it up automatically.
enum _MapStyle {
  dark(
    label: 'DARK',
    description: 'Brand-aligned night view',
    urlTemplate:
        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
    subdomains: ['a', 'b', 'c', 'd'],
    source: _TileSource.carto,
  ),
  light(
    label: 'LIGHT',
    description: 'Clean daytime view',
    urlTemplate:
        'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    subdomains: ['a', 'b', 'c', 'd'],
    source: _TileSource.carto,
  ),
  voyager(
    label: 'VOYAGER',
    description: 'Colourful — pins pop',
    urlTemplate:
        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
    subdomains: ['a', 'b', 'c', 'd'],
    source: _TileSource.carto,
  ),
  standard(
    label: 'STANDARD',
    description: 'Classic OpenStreetMap',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    subdomains: <String>[],
    source: _TileSource.osm,
  );

  const _MapStyle({
    required this.label,
    required this.description,
    required this.urlTemplate,
    required this.subdomains,
    required this.source,
  });

  final String label;
  final String description;
  final String urlTemplate;
  final List<String> subdomains;
  final _TileSource source;

  // Pin colour suggestion — keep the brand orange on dark/voyager (high
  // contrast); on the light style use a slightly darker fill so the pin still
  // reads against a near-white background without changing the action token.
  bool get prefersDarkText => this == _MapStyle.light;
}

enum _TileSource { carto, osm }

const String _kMapStylePrefsKey = 'home.map_style';

class _MapView extends StatefulWidget {
  const _MapView({
    required this.jobs,
    required this.placeLabel,
    required this.onJobTap,
  });

  final List<Job> jobs;
  // Suburb/state string used for the "NEAR <place> • 5 KM" radius chip.
  final String placeLabel;
  final ValueChanged<Job> onJobTap;

  @override
  State<_MapView> createState() => _MapViewState();
}

// Search radius rendered as both a translucent circle on the map and a chip
// in the top-left. Tweak in one place if product wants a different default.
const double _kSearchRadiusKm = 5.0;

// Outcome of the current location request — drives the in-map banner UX.
enum _LocationStatus {
  idle,
  requesting,
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  error,
}

class _MapViewState extends State<_MapView> {
  static const _sydney = LatLng(-33.8688, 151.2093);

  final MapController _controller = MapController();
  _MapStyle _style = _MapStyle.voyager;
  LatLng? _userLocation;
  _LocationStatus _locationStatus = _LocationStatus.idle;

  @override
  void initState() {
    super.initState();
    _loadStyle();
    // Defer to post-frame so the rationale dialog doesn't fight the map's
    // first render. Permission ask happens on entry to the map view — that
    // context is the strongest signal the user wants location used.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initLocation();
    });
  }

  Future<void> _loadStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kMapStylePrefsKey);
    if (raw == null || !mounted) return;
    final found = _MapStyle.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => _MapStyle.voyager,
    );
    if (found != _style) setState(() => _style = found);
  }

  Future<void> _setStyle(_MapStyle next) async {
    setState(() => _style = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMapStylePrefsKey, next.name);
  }

  // Full location request lifecycle:
  //   1. Service enabled? (device GPS toggle)
  //   2. Permission state — if denied, show rationale BEFORE the native prompt
  //   3. Fetch position (10s budget, medium accuracy — city-block is enough)
  //   4. Centre the map on success; surface banner on every failure mode
  Future<void> _initLocation() async {
    setState(() => _locationStatus = _LocationStatus.requesting);

    if (!await Geolocator.isLocationServiceEnabled()) {
      if (!mounted) return;
      setState(() => _locationStatus = _LocationStatus.serviceDisabled);
      return;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      if (!mounted) return;
      final agreed = await _showRationaleDialog();
      if (!mounted) return;
      if (!agreed) {
        setState(() => _locationStatus = _LocationStatus.denied);
        return;
      }
      permission = await Geolocator.requestPermission();
    }

    if (!mounted) return;

    if (permission == LocationPermission.deniedForever) {
      setState(() => _locationStatus = _LocationStatus.deniedForever);
      return;
    }
    if (permission == LocationPermission.denied) {
      setState(() => _locationStatus = _LocationStatus.denied);
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _userLocation = latLng;
        _locationStatus = _LocationStatus.granted;
      });
      // Zoom 12 matches the initial framing so the 5 km radius circle fits
      // comfortably in view after the camera moves to the user.
      _controller.move(latLng, 12);
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationStatus = _LocationStatus.error);
    }
  }

  // Custom rationale — shown ONCE per request, before the OS prompt. Gives
  // the user a Jobdun-branded explanation instead of the bare native dialog
  // that says nothing about why we want it.
  Future<bool> _showRationaleDialog() async {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2.r)),
        title: Text(
          'SHOW JOBS NEAR YOU',
          style: tt.headlineSmall!.copyWith(color: c.text1, letterSpacing: 0.5),
        ),
        content: Text(
          'Jobdun needs your location to centre the map on you and surface '
          'jobs nearby. We only use it while you have the map open — never in '
          'the background.',
          style: tt.bodyMedium!.copyWith(color: c.text2, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'NOT NOW',
              style: tt.labelLarge!.copyWith(
                color: c.text2,
                letterSpacing: 0.5,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'CONTINUE',
              style: tt.labelLarge!.copyWith(
                color: c.action,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openSettings() async {
    await Geolocator.openAppSettings();
  }

  // Effective centre for the search radius + sample-pin spread: actual user
  // GPS if granted, otherwise the Sydney default. Stays a LatLng (not nullable)
  // so the CircleLayer + sample generator always have something to anchor on.
  LatLng get _radiusCenter => _userLocation ?? _sydney;

  // Real jobs win whenever they're available; otherwise we synthesize a
  // small set of clickable pins inside the radius so the map view always
  // demos end-to-end (pin → tap → detail page).
  List<Job> get _effectiveJobs =>
      widget.jobs.isNotEmpty ? widget.jobs : _sampleJobsAround(_radiusCenter);

  List<Marker> _buildMarkers(Color pinColor, Color pinBorder) {
    return [
      for (final job in _effectiveJobs)
        if (job.latitude != null && job.longitude != null)
          Marker(
            point: LatLng(job.latitude!, job.longitude!),
            width: 40,
            height: 40,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onJobTap(job),
              child: Container(
                decoration: BoxDecoration(
                  color: pinColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: pinBorder, width: 2),
                ),
                child: const Icon(
                  AppIcons.locationFilled,
                  size: 20,
                  color: Colors.white, // intentional: white-on-action
                ),
              ),
            ),
          ),
      // User position — solid white dot with brand-orange ring. Clearly
      // distinct from the orange job pins above so the user can tell
      // "where I am" from "what's around me" at a glance.
      if (_userLocation != null)
        Marker(
          point: _userLocation!,
          width: 22,
          height: 22,
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white, // intentional: white-on-action
              shape: BoxShape.circle,
              border: Border.all(color: pinColor, width: 3),
            ),
          ),
        ),
    ];
  }

  List<TextSourceAttribution> _attributionsFor(_MapStyle style) {
    return [
      TextSourceAttribution(
        'OpenStreetMap contributors',
        onTap: () =>
            launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
      ),
      if (style.source == _TileSource.carto)
        TextSourceAttribution(
          'CARTO',
          onTap: () => launchUrl(Uri.parse('https://carto.com/attribution')),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: const MapOptions(
            initialCenter: _sydney,
            // Zoom 12 frames the 5 km search radius cleanly without clipping
            // the outer ring on a typical phone viewport.
            initialZoom: 12,
            minZoom: 3,
            maxZoom: 18,
            interactionOptions: InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              // Keyed so flutter_map drops the old tile cache when the
              // template changes — otherwise mixed-style tiles flash during
              // the swap.
              key: ValueKey<_MapStyle>(_style),
              urlTemplate: _style.urlTemplate,
              subdomains: _style.subdomains,
              retinaMode: RetinaMode.isHighDensity(context),
              userAgentPackageName: 'com.example.jobdun',
            ),
            // Search-radius circle drawn under the markers so pins sit on top.
            // Uses meters for the radius so it scales with the zoom level —
            // that's the visual cue the user actually reads as "your area".
            CircleLayer(
              circles: [
                CircleMarker(
                  point: _radiusCenter,
                  radius: _kSearchRadiusKm * 1000,
                  useRadiusInMeter: true,
                  color: c.action.withValues(alpha: 0.10),
                  borderColor: c.action,
                  borderStrokeWidth: 1.5,
                ),
              ],
            ),
            MarkerLayer(markers: _buildMarkers(c.action, c.surface)),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: _attributionsFor(_style),
            ),
          ],
        ),
        // Top-left radius chip — tells the user exactly what they're looking
        // at: the suburb name and the search radius the pins are filtered by.
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12.w, 12.h, 0, 0),
              child: _RadiusChip(
                placeLabel: widget.placeLabel,
                radiusKm: _kSearchRadiusKm,
              ),
            ),
          ),
        ),
        // Top-right floating controls. SafeArea pushes them below the status
        // bar/notch; the Column gives the style chip and recenter button a
        // consistent 8.h gap so they never overlap each other.
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, 12.h, 12.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapStyleButton(
                    current: _style,
                    onTap: () async {
                      final next = await _showStyleSheet(context, _style);
                      if (next != null && next != _style) {
                        await _setStyle(next);
                      }
                    },
                  ),
                  Gap(8.h),
                  _RecenterButton(
                    isLoading: _locationStatus == _LocationStatus.requesting,
                    hasLocation: _userLocation != null,
                    onTap: () {
                      if (_userLocation != null) {
                        // Match the initial framing zoom so the radius circle
                        // stays visible after recentering.
                        _controller.move(_userLocation!, 12);
                      } else {
                        _initLocation();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_locationStatus == _LocationStatus.denied ||
            _locationStatus == _LocationStatus.deniedForever ||
            _locationStatus == _LocationStatus.serviceDisabled ||
            _locationStatus == _LocationStatus.error)
          Positioned(
            left: 12.w,
            right: 12.w,
            bottom: 12.h,
            child: _LocationStatusBanner(
              status: _locationStatus,
              onRetry: _initLocation,
              onOpenSettings: _openSettings,
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// Top-left chip: "NEAR PARRAMATTA, NSW · 5 KM". Tells the user exactly which
// location the radius circle is anchored on and how far out the pins reach.
// Pure presentation — the actual circle is rendered by the CircleLayer in
// _MapView.build.
class _RadiusChip extends StatelessWidget {
  const _RadiusChip({required this.placeLabel, required this.radiusKm});

  final String placeLabel;
  final double radiusKm;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    // Trim a trailing ", NSW" / ", VIC" etc. — the chip is already tight on
    // horizontal real estate when paired with the style/recenter column.
    final shortPlace = placeLabel.split(',').first.trim().toUpperCase();
    final radiusText = radiusKm == radiusKm.roundToDouble()
        ? '${radiusKm.toInt()} KM'
        : '${radiusKm.toStringAsFixed(1)} KM';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border, width: 1),
        borderRadius: BorderRadius.circular(2.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.location, size: 16.r, color: c.action),
          Gap(6.w),
          Text(
            'NEAR $shortPlace',
            style: tt.labelSmall!.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          Gap(8.w),
          Container(width: 1, height: 12.h, color: c.border),
          Gap(8.w),
          Text(
            radiusText,
            style: tt.labelSmall!.copyWith(
              color: c.action,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// Compact corner button — flat, hard edges, brand-orange icon on surface.
class _MapStyleButton extends StatelessWidget {
  const _MapStyleButton({required this.current, required this.onTap});

  final _MapStyle current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border, width: 1),
            borderRadius: BorderRadius.circular(2.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.mapLayer, size: 16.r, color: c.action),
              Gap(6.w),
              Text(
                current.label,
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  color: c.text1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<_MapStyle?> _showStyleSheet(BuildContext context, _MapStyle current) {
  return showJSheet<_MapStyle>(
    context: context,
    builder: (_) => _MapStyleSheet(current: current),
  );
}

class _MapStyleSheet extends StatelessWidget {
  const _MapStyleSheet({required this.current});

  final _MapStyle current;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(2.r)),
          border: Border(top: BorderSide(color: c.action, width: 3)),
        ),
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'MAP STYLE',
              style: tt.headlineSmall!.copyWith(
                color: c.text1,
                letterSpacing: 0.5,
              ),
            ),
            Gap(4.h),
            Text(
              'Pick the look that fits how you read maps.',
              style: tt.bodySmall!.copyWith(color: c.text2),
            ),
            Gap(16.h),
            for (final style in _MapStyle.values) ...[
              _MapStyleRow(
                style: style,
                selected: style == current,
                onTap: () => Navigator.of(context).pop(style),
              ),
              if (style != _MapStyle.values.last) Gap(8.h),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapStyleRow extends StatelessWidget {
  const _MapStyleRow({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final _MapStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          border: Border.all(
            color: selected ? c.action : c.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(2.r),
        ),
        child: Row(
          children: [
            Container(
              width: 32.r,
              height: 32.r,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? c.action : c.surface,
                borderRadius: BorderRadius.circular(2.r),
              ),
              child: Icon(
                AppIcons.mapLayer,
                size: 16.r,
                color: selected
                    ? Colors
                          .white // intentional: white-on-action
                    : c.text2,
              ),
            ),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style.label,
                    style: tt.labelLarge!.copyWith(
                      color: c.text1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Gap(2.h),
                  Text(
                    style.description,
                    style: tt.bodySmall!.copyWith(color: c.text2),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(AppIcons.successCircleFilled, size: 18.r, color: c.action),
          ],
        ),
      ),
    );
  }
}

// Locate-me button. Tap when we already have a fix → recentre the map.
// Tap when we don't → kick off the full request flow (rationale → prompt →
// fetch). While in-flight, swap the icon for a spinner so it can't be
// double-tapped.
class _RecenterButton extends StatelessWidget {
  const _RecenterButton({
    required this.isLoading,
    required this.hasLocation,
    required this.onTap,
  });

  final bool isLoading;
  final bool hasLocation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        child: Container(
          width: 36.r,
          height: 36.r,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border, width: 1),
            borderRadius: BorderRadius.circular(2.r),
          ),
          child: isLoading
              ? SizedBox.square(
                  dimension: 14.r,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.action,
                  ),
                )
              : Icon(
                  hasLocation ? AppIcons.gpsFilled : AppIcons.gps,
                  size: 18.r,
                  color: c.action,
                ),
        ),
      ),
    );
  }
}

// Inline banner surfaced at the bottom of the map when location can't be
// fetched. Copy + CTA change per failure mode so the user knows exactly
// what to do (vs a generic "permission needed" message).
class _LocationStatusBanner extends StatelessWidget {
  const _LocationStatusBanner({
    required this.status,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final _LocationStatus status;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    final (title, body, ctaLabel, ctaAction) = switch (status) {
      _LocationStatus.serviceDisabled => (
        'LOCATION OFF',
        'Turn on device location to see jobs near you.',
        'RETRY',
        onRetry,
      ),
      _LocationStatus.denied => (
        'LOCATION DENIED',
        'Allow location access to centre the map on you.',
        'ALLOW',
        onRetry,
      ),
      _LocationStatus.deniedForever => (
        'LOCATION BLOCKED',
        "Permission is blocked. Enable it in your phone's settings.",
        'SETTINGS',
        onOpenSettings,
      ),
      _LocationStatus.error => (
        "COULDN'T LOCATE",
        'Take a moment, then try again.',
        'RETRY',
        onRetry,
      ),
      _ => ('', '', '', onRetry),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border, width: 1),
        borderRadius: BorderRadius.circular(2.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(AppIcons.locationUnavailable, size: 18.r, color: c.action),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: tt.labelLarge!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Gap(2.h),
                Text(body, style: tt.bodySmall!.copyWith(color: c.text2)),
              ],
            ),
          ),
          Gap(8.w),
          TextButton(
            onPressed: ctaAction,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            child: Text(
              ctaLabel,
              style: tt.labelLarge!.copyWith(
                color: c.action,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
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

const _mockJobs = [
  _MockJob(
    title: 'Install 3-phase switchboard at commercial site',
    description:
        'Install a 3-phase switchboard at our commercial fit-out in Surry Hills. Conduit run, panel installation, and termination.',
    rate: r'$85/hr',
    startDate: 'Tomorrow',
    distanceKm: 2.4,
    isUrgent: true,
  ),
  _MockJob(
    title: 'Frame internal walls for home renovation',
    description:
        'Steel stud framing approximately 120 LM for a full home renovation in Newtown. Drawings available on site.',
    rate: r'$45/hr',
    startDate: '12 May',
    distanceKm: 4.8,
    isUrgent: false,
  ),
  _MockJob(
    title: 'Concrete footings for deck extension',
    description:
        '8 × 300mm dia pad footings, 600mm deep. Reinforcement to be supplied by contractor.',
    rate: r'$75/hr',
    startDate: '14 May',
    distanceKm: 9.1,
    isUrgent: false,
  ),
];

// Demo job pins generated around a given centre — used by the map view when
// there is no real Supabase data with location yet. Pins are offset within
// roughly the 5 KM search radius so the user sees the radius circle "filled"
// with jobs wherever they happen to be testing (not just in Sydney).
//
// Each template is a const description of the job; coords are computed at
// runtime by adding the dLat / dLng offset to [center]. Distances assume
// ~111 km per degree latitude / longitude near the equator — close enough
// for tradesperson-scale radii (within a couple percent at -33° lat).
class _SampleJobTemplate {
  const _SampleJobTemplate({
    required this.idSuffix,
    required this.title,
    required this.description,
    required this.trade,
    required this.urgency,
    required this.budgetMin,
    this.budgetMax,
    required this.daysOut,
    required this.dLat,
    required this.dLng,
  });

  final String idSuffix;
  final String title;
  final String description;
  final String trade;
  final JobUrgency urgency;
  final double budgetMin;
  final double? budgetMax;
  final int daysOut;
  final double dLat;
  final double dLng;
}

const _sampleJobTemplates = <_SampleJobTemplate>[
  _SampleJobTemplate(
    idSuffix: 'switchboard',
    title: 'Install 3-phase switchboard',
    description:
        'Commercial fit-out. Conduit run, panel installation, and termination on a 3-phase board.',
    trade: 'Electrician',
    urgency: JobUrgency.urgent,
    budgetMin: 85,
    daysOut: 1,
    dLat: 0.018,
    dLng: 0.022,
  ),
  _SampleJobTemplate(
    idSuffix: 'framing',
    title: 'Frame internal walls — home reno',
    description:
        'Steel-stud framing ~120 LM for a full home renovation. Drawings on site.',
    trade: 'Carpenter',
    urgency: JobUrgency.standard,
    budgetMin: 45,
    daysOut: 3,
    dLat: -0.022,
    dLng: 0.012,
  ),
  _SampleJobTemplate(
    idSuffix: 'footings',
    title: 'Concrete footings for deck extension',
    description:
        '8 × 300mm dia pad footings, 600mm deep. Reinforcement supplied by contractor.',
    trade: 'Concreter',
    urgency: JobUrgency.standard,
    budgetMin: 75,
    daysOut: 5,
    dLat: 0.008,
    dLng: -0.025,
  ),
  _SampleJobTemplate(
    idSuffix: 'plumbing',
    title: 'Bathroom rough-in — townhouse',
    description:
        'Hot/cold + waste rough-in across two new bathrooms. PEX-A throughout.',
    trade: 'Plumber',
    urgency: JobUrgency.standard,
    budgetMin: 95,
    daysOut: 2,
    dLat: -0.014,
    dLng: -0.018,
  ),
  _SampleJobTemplate(
    idSuffix: 'roofing',
    title: 'Roof tile repair — storm damage',
    description:
        'Storm-damaged terracotta tiles. Approx 40 tiles to replace + flashing repair.',
    trade: 'Roofer',
    urgency: JobUrgency.urgent,
    budgetMin: 65,
    budgetMax: 85,
    daysOut: 1,
    dLat: 0.025,
    dLng: -0.005,
  ),
];

List<Job> _sampleJobsAround(LatLng center) {
  final now = DateTime.now();
  return [
    for (final t in _sampleJobTemplates)
      Job(
        id: 'sample-${t.idSuffix}',
        builderId: 'sample-builder',
        title: t.title,
        description: t.description,
        tradeTypeRequired: t.trade,
        // No real reverse-geocoding yet — the radius chip carries the place
        // label for the user. Suburb here is a generic placeholder shown
        // on the detail screen.
        suburb: 'Nearby',
        state: 'NSW',
        postcode: '',
        status: JobStatus.open,
        urgency: t.urgency,
        budgetMin: t.budgetMin,
        budgetMax: t.budgetMax,
        budgetType: BudgetType.hourly,
        startDate: now.add(Duration(days: t.daysOut)),
        createdAt: now,
        updatedAt: now,
        latitude: center.latitude + t.dLat,
        longitude: center.longitude + t.dLng,
      ),
  ];
}
