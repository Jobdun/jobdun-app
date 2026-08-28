import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/services/ftue_analytics.dart';
import '../../../../core/services/ftue_service.dart';
import '../providers/ftue_geo_provider.dart';
import '../slides/slide_one_trust.dart';
import '../slides/slide_three_action.dart';
import '../slides/slide_two_speed.dart';
import '../widgets/ftue_role_sheet.dart';

// Three-slide FTUE carousel, rebuilt on the Figma "Onboard" design
// (JobDun-Screens, node 17:5084). New installs land here straight out of
// splash; every exit path sets has_completed_ftue=true so the user never sees
// it again.
//
// The layout splits in two: the hero + headline swipe, the role sheet
// underneath does not. Because both roles, the log-in link and guest browsing
// are on screen from slide 1, the old SKIP affordance is gone — there is
// nothing left for it to shortcut.
//
// [fromLogin] is true when the user tapped "Create account →" on /login — they
// already know the app and just need a signup path. A back caret then returns
// them to /login from slide 1, and steps back a slide from anywhere else. The
// FTUE is entered via context.go (empty stack), so without that escape system
// back exits the app outright (live bug S4, 2026-08-18).
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
    // Kick off the IP-geo lookup in parallel with the user reading slide 1, so
    // the personalised copy is ready by the time they swipe to slide 2.
    // listenManual (vs ref.read) keeps the autoDispose provider alive for the
    // lifetime of the FTUE — without a subscription it would dispose right
    // after the initial read and slide 2 would have to refire the lookup on
    // mount, defeating the parallelism.
    ref.listenManual(ftueGeoProvider, (_, _) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // precacheImage needs a BuildContext with an attached ImageConfiguration,
    // which isn't available in initState. Guard so we only fire once across
    // route rebuilds. Errors swallowed — FtueHero's errorBuilder takes over
    // for a missing asset.
    if (_heroPrecached) return;
    _heroPrecached = true;
    for (final asset in const [
      SlideOneTrust.heroAsset,
      SlideTwoSpeed.heroAsset,
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

  void _onCta(String role) {
    FtueAnalytics.ctaTapped(role: role);
    _exit(exitPath: 'cta', route: '/register?role=$role');
  }

  void _onLoginLink() {
    FtueAnalytics.loginLinkTapped(fromSlide: _currentSlide);
    _exit(exitPath: 'login_link', route: '/login');
  }

  // Guest browsing (App Review 5.1.1(v)) — straight to the public job browser,
  // no account. Marks the FTUE complete like every other exit.
  void _onBrowse() {
    _exit(exitPath: 'guest_browse', route: '/browse');
  }

  void _onBack() {
    if (_currentSlide > 0) {
      _pageController.previousPage(
        duration: AppMotion.medium,
        curve: AppMotion.standard,
      );
    } else if (widget.fromLogin) {
      if (_exited) return;
      _exited = true;
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final showBack = widget.fromLogin || _currentSlide > 0;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return PopScope(
      canPop: _currentSlide == 0 && !widget.fromLogin,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // The hero bleeds under the status bar, so the icons have to be picked
        // against the photo's pale top edge rather than the app chrome.
        value: isLight
            ? SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              ),
        child: Scaffold(
          backgroundColor: c.background,
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    // Web and desktop need this. Flutter's default
                    // ScrollBehavior only accepts touch drags, so on
                    // app.jobdun.com.au the carousel could not be swiped with a
                    // mouse at all — and it painted a horizontal scrollbar over
                    // the hero as the only affordance. Allow mouse/trackpad
                    // drags and drop the scrollbar; the page bars below are
                    // tappable as a second route through.
                    ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        scrollbars: false,
                        overscroll: false,
                        dragDevices: const {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.trackpad,
                          PointerDeviceKind.stylus,
                        },
                      ),
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        children: [
                          SlideOneTrust(
                            controller: _pageController,
                            slideCount: _slideCount,
                          ),
                          SlideTwoSpeed(
                            controller: _pageController,
                            slideCount: _slideCount,
                          ),
                          SlideThreeAction(
                            controller: _pageController,
                            slideCount: _slideCount,
                          ),
                        ],
                      ),
                    ),
                    if (showBack)
                      SafeArea(
                        bottom: false,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.sm.w),
                            child: _BackButton(
                              onTap: _onBack,
                              label: _currentSlide == 0
                                  ? 'Back to log in.'
                                  : 'Back to previous slide.',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: FtueRoleSheet(
                  onFindWork: () => _onCta('trade'),
                  onHireWorkers: () => _onCta('builder'),
                  onLogin: _onLoginLink,
                  onBrowse: _onBrowse,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Back caret ───────────────────────────────────────────────────────────────
// Not in the Figma frame, but the S4 fix needs an on-screen escape: the FTUE is
// entered with an empty navigation stack, so on iOS (no system back) a user who
// arrived from /login would otherwise be stranded. Rendered as a translucent
// disc so it reads as chrome floating on the photo, not part of the artwork.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: c.surface.withValues(alpha: 0.85),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.sm.r),
            child: Icon(
              AppIcons.arrowLeft,
              size: AppIconSize.md.r,
              color: c.text1,
            ),
          ),
        ),
      ),
    );
  }
}
