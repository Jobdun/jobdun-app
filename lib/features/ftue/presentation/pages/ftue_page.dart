import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/ftue_analytics.dart';
import '../../../../core/services/ftue_service.dart';
import '../../../auth/presentation/widgets/role_intent_cta.dart';
import '../widgets/ftue_page_indicator.dart';
import '../widgets/ftue_slide.dart';

// Three-slide FTUE carousel. New installs land here straight out of splash;
// every exit path (CTA tap, SKIP, login link) sets has_completed_ftue=true so
// the user never sees it again.
class FtuePage extends ConsumerStatefulWidget {
  const FtuePage({super.key});

  @override
  ConsumerState<FtuePage> createState() => _FtuePageState();
}

class _FtuePageState extends ConsumerState<FtuePage> {
  static const _slideCount = 3;

  final _pageController = PageController();
  int _currentSlide = 0;
  // Per-slide enter timestamps drive the time_on_previous_ms analytics
  // payload — without this, the "are slides 1 and 2 too long?" question is
  // unanswerable.
  late final DateTime _startedAt;
  late DateTime _slideEnteredAt;
  bool _exited = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startedAt = now;
    _slideEnteredAt = now;
    FtueAnalytics.started(entry: 'first_launch');
    // Slide 0 view fires here so the funnel has a "saw slide 1" event even
    // for users who exit before swiping.
    FtueAnalytics.slideViewed(slideIndex: 0, timeOnPreviousMs: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    final now = DateTime.now();
    final delta = now.difference(_slideEnteredAt).inMilliseconds;
    setState(() {
      _currentSlide = index;
      _slideEnteredAt = now;
    });
    FtueAnalytics.slideViewed(slideIndex: index, timeOnPreviousMs: delta);
  }

  Future<void> _exit({required String exitPath, required String route}) async {
    if (_exited) return;
    _exited = true;
    await FtueService.markFtueComplete();
    FtueAnalytics.completed(
      exitPath: exitPath,
      totalTimeMs: DateTime.now().difference(_startedAt).inMilliseconds,
    );
    if (!mounted) return;
    context.go(route);
  }

  void _onSkip() {
    FtueAnalytics.skipped(fromSlide: _currentSlide);
    _exit(exitPath: 'skip', route: '/login');
  }

  void _onCta(String role) {
    FtueAnalytics.ctaTapped(role: role);
    _exit(exitPath: 'cta', route: '/register?role=$role');
  }

  void _onLoginLink() {
    FtueAnalytics.loginLinkTapped(fromSlide: _currentSlide);
    _exit(exitPath: 'login_link', route: '/login');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isFinalSlide = _currentSlide == _slideCount - 1;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(showSkip: !isFinalSlide, onSkip: _onSkip),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  FtueSlide(
                    headlineLine1: 'VERIFIED TRADIES.',
                    headlineLine2: 'REAL JOBS.',
                    body:
                        'Every trade is licence-checked. Every builder is '
                        'verified. No timewasters.',
                    visual: const _VerifiedBadgeStack(),
                  ),
                  FtueSlide(
                    headlineLine1: 'FIND WORK.',
                    headlineLine2: 'FAST.',
                    body:
                        'Jobs near you, sorted by your suburb. Apply in '
                        'three taps.',
                    visual: const _MapPinCluster(),
                  ),
                  FtueSlide(
                    headlineLine1: 'BUILT FOR',
                    headlineLine2: 'AUSSIE SITES.',
                    body:
                        'Made in Australia. For builders, sparkies, chippies, '
                        'plumbers, and crews.',
                    visual: const _AussieMark(),
                    footer: _FinalSlideCtas(
                      onHiring: () => _onCta('builder'),
                      onWorking: () => _onCta('trade'),
                      onLoginLink: _onLoginLink,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.lg.h),
              child: FtuePageIndicator(
                controller: _pageController,
                count: _slideCount,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top bar ─────────────────────────────────────────────────────────────────
// Indicator lives at the bottom; this just hosts the SKIP affordance.
// Always-mounted with a fixed height so swiping to slide 3 doesn't cause a
// layout shift when SKIP disappears.

class _TopBar extends StatelessWidget {
  const _TopBar({required this.showSkip, required this.onSkip});

  final bool showSkip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return SizedBox(
      height: 44.h,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
        child: Row(
          children: [
            const Spacer(),
            if (showSkip)
              Semantics(
                button: true,
                label: 'Skip introduction. Go to log in.',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onSkip,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    child: Text(
                      'SKIP',
                      style: tt.labelMedium!.copyWith(
                        color: c.text2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Final-slide CTA stack ───────────────────────────────────────────────────
// Reuses RoleIntentCta from the auth feature — same role-deep-link pattern
// the login page used before this refactor moved them here.

class _FinalSlideCtas extends StatelessWidget {
  const _FinalSlideCtas({
    required this.onHiring,
    required this.onWorking,
    required this.onLoginLink,
  });

  final VoidCallback onHiring;
  final VoidCallback onWorking;
  final VoidCallback onLoginLink;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RoleIntentCta(
          icon: Iconsax.buildings,
          label: "I'M HIRING",
          subtitle: 'Post a job. Get quotes from verified crews.',
          onTap: onHiring,
        ),
        Gap(12.h),
        RoleIntentCta(
          icon: Iconsax.briefcase,
          label: "I'M LOOKING FOR WORK",
          subtitle: 'Find jobs near you. Built for Aussie trades.',
          onTap: onWorking,
        ),
        Gap(AppSpacing.md.h),
        // Two-line stack (not a single Row) keeps the link readable on
        // narrow 360-wide devices and gives the test harness a generously
        // sized, always-on-screen tap target — Ahem-font glyphs in widget
        // tests are wide enough to push a single-row layout off-bounds.
        Semantics(
          button: true,
          label: 'I already have an account. Log in.',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onLoginLink,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'I already have an account',
                    textAlign: TextAlign.center,
                    style: tt.bodySmall!.copyWith(color: c.text3),
                  ),
                  Gap(4.h),
                  Text(
                    'LOG IN',
                    textAlign: TextAlign.center,
                    style: tt.bodySmall!.copyWith(
                      color: c.text2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      decoration: TextDecoration.underline,
                      decorationColor: c.text2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Visual placeholders ─────────────────────────────────────────────────────
// Static Iconsax compositions. Lottie ships in the next sprint and slots into
// the `visual:` parameter without touching FtueSlide.

class _VerifiedBadgeStack extends StatelessWidget {
  const _VerifiedBadgeStack();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 0,
          child: _Badge(icon: Iconsax.shield_tick, color: c.verified),
        ),
        Positioned(
          right: 0,
          child: _Badge(icon: Iconsax.verify, color: c.action),
        ),
        _Badge(icon: Iconsax.shield_tick, color: c.action, large: true),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color, this.large = false});

  final IconData icon;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final size = large ? 96.r : 64.r;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Icon(icon, size: large ? 48.r : 28.r, color: color),
    );
  }
}

class _MapPinCluster extends StatelessWidget {
  const _MapPinCluster();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 6.h,
          left: 24.w,
          child: Icon(Iconsax.location, size: 40.r, color: c.text3),
        ),
        Positioned(
          bottom: 6.h,
          right: 28.w,
          child: Icon(Iconsax.location, size: 36.r, color: c.text2),
        ),
        Container(
          width: 96.r,
          height: 96.r,
          decoration: BoxDecoration(
            color: c.surface,
            shape: BoxShape.circle,
            border: Border.all(color: c.border),
          ),
          child: Icon(Iconsax.location5, size: 48.r, color: c.action),
        ),
      ],
    );
  }
}

class _AussieMark extends StatelessWidget {
  const _AussieMark();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 120.r,
      height: 120.r,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Icon(Iconsax.building_4, size: 64.r, color: c.action),
    );
  }
}
