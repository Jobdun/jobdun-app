import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/services/ftue_analytics.dart';
import '../../../../core/services/ftue_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/ftue_geo_provider.dart';
import '../slides/slide_one_trust.dart';
import '../slides/slide_three_action.dart';
import '../slides/slide_two_speed.dart';
import '../widgets/ftue_page_indicator.dart';

// Three-slide FTUE carousel. New installs land here straight out of splash;
// every exit path (CTA tap, SKIP, login link) sets has_completed_ftue=true
// so the user never sees it again.
//
// [fromLogin] is true when the user tapped "Create account →" on /login —
// they already know the app, just need a signup path. In that case slide 1
// shows a back-arrow (return to /login) and slide 3 hides the redundant
// "I already have an account · LOG IN" footer link.
class FtuePage extends ConsumerStatefulWidget {
  const FtuePage({super.key, this.fromLogin = false});

  final bool fromLogin;

  @override
  ConsumerState<FtuePage> createState() => _FtuePageState();
}

class _FtuePageState extends ConsumerState<FtuePage> {
  static const _slideCount = 3;

  final _pageController = PageController();
  int _currentSlide = 0;
  late final DateTime _startedAt;
  late DateTime _slideEnteredAt;
  bool _exited = false;
  bool _heroPrecached = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startedAt = now;
    _slideEnteredAt = now;
    FtueAnalytics.started(
      entry: widget.fromLogin ? 'create_account_link' : 'first_launch',
    );
    FtueAnalytics.slideViewed(slideIndex: 0, timeOnPreviousMs: 0);
    // Kick off the IP-geo lookup in parallel with the user reading slide 1
    // so by the time they swipe to slide 2 the personalised copy is ready.
    // listenManual (vs ref.read) keeps the autoDispose provider alive for
    // the lifetime of the FTUE — without a subscription it would dispose
    // immediately after the initial read and slide 2 would have to refire
    // the lookup on mount, defeating the parallelism.
    ref.listenManual(ftueGeoProvider, (_, _) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // precacheImage needs a BuildContext with an attached ImageConfiguration,
    // which isn't available in initState. Guard so we only fire once across
    // route rebuilds. Errors swallowed — the FtueHeroPhoto errorBuilder
    // takes over for missing assets.
    if (_heroPrecached) return;
    _heroPrecached = true;
    for (final asset in const [
      SlideOneTrust.heroAsset,
      SlideThreeAction.heroAsset,
    ]) {
      precacheImage(AssetImage(asset), context).catchError((_) {});
    }
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

  /// Shortcut for users who'd rather skip the role + email signup form and
  /// jump straight to Google SSO. The router redirect listens to auth state
  /// and routes to /home automatically on success; OnboardingCompletionSheet
  /// then collects role + name + optional avatar in a single sheet.
  Future<void> _onContinueWithGoogle() async {
    if (_exited) return;
    _exited = true;
    FtueAnalytics.completed(
      exitPath: 'google_sso',
      totalTimeMs: DateTime.now().difference(_startedAt).inMilliseconds,
    );
    await FtueService.markFtueComplete();
    if (!mounted) return;
    // Don't navigate — auth-state listener in app_router redirects to /home
    // (or /splash → /home) once the session is established.
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
  }

  void _onBackToLogin() {
    if (_exited) return;
    _exited = true;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isFinalSlide = _currentSlide == _slideCount - 1;
    final showBack = widget.fromLogin && _currentSlide == 0;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              showSkip: !isFinalSlide,
              onSkip: _onSkip,
              showBack: showBack,
              onBack: _onBackToLogin,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  const SlideOneTrust(),
                  const SlideTwoSpeed(),
                  SlideThreeAction(
                    onHiring: () => _onCta('builder'),
                    onWorking: () => _onCta('trade'),
                    onContinueWithGoogle: _onContinueWithGoogle,
                    onLoginLink: widget.fromLogin ? null : _onLoginLink,
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
  const _TopBar({
    required this.showSkip,
    required this.onSkip,
    this.showBack = false,
    this.onBack,
  });

  final bool showSkip;
  final VoidCallback onSkip;
  final bool showBack;
  final VoidCallback? onBack;

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
            if (showBack && onBack != null)
              Semantics(
                button: true,
                label: 'Back to log in.',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onBack,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 10.h,
                    ),
                    child: Icon(AppIcons.arrowLeft, size: 22.r, color: c.text2),
                  ),
                ),
              ),
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
