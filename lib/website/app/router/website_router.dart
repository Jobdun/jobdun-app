import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/website/presentation/pages/contact_page.dart';
import '../../features/website/presentation/pages/for_builders_page.dart';
import '../../features/website/presentation/pages/for_crews_page.dart';
import '../../features/website/presentation/pages/home_page.dart';
import '../../features/website/presentation/pages/pricing_page.dart';

/// Routes for the Jobdun marketing site. The home page is the full single-
/// scroll story; the sub-pages (`/for-builders`, `/for-crews`, `/pricing`,
/// `/contact`) are audience- and conversion-focused and share the same chrome
/// via `SiteShell`.
///
/// `/privacy` and `/delete-account` are NOT routed through Flutter; they remain
/// plain HTML in `site/` (faster first paint, no Flutter boot for legal pages,
/// Cloudflare Pages serves them directly).
final websiteRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        pageBuilder: (context, state) =>
            _fadeThroughPage(context, state, const HomePage()),
      ),
      GoRoute(
        path: '/for-builders',
        name: 'for-builders',
        pageBuilder: (context, state) =>
            _fadeThroughPage(context, state, const ForBuildersPage()),
      ),
      GoRoute(
        path: '/for-crews',
        name: 'for-crews',
        pageBuilder: (context, state) =>
            _fadeThroughPage(context, state, const ForCrewsPage()),
      ),
      GoRoute(
        path: '/pricing',
        name: 'pricing',
        pageBuilder: (context, state) =>
            _fadeThroughPage(context, state, const PricingPage()),
      ),
      GoRoute(
        path: '/contact',
        name: 'contact',
        pageBuilder: (context, state) =>
            _fadeThroughPage(context, state, const ContactPage()),
      ),
    ],
  );
});

/// Wraps a destination in a Material "fade through" page transition. The
/// correct pattern for switching between peer top-level destinations. Falls
/// back to an instant cut under reduced-motion.
CustomTransitionPage<void> _fadeThroughPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220),
    reverseTransitionDuration: reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (reduceMotion) return child;
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
    },
  );
}
