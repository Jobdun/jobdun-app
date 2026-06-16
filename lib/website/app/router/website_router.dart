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
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/for-builders',
        name: 'for-builders',
        builder: (context, state) => const ForBuildersPage(),
      ),
      GoRoute(
        path: '/for-crews',
        name: 'for-crews',
        builder: (context, state) => const ForCrewsPage(),
      ),
      GoRoute(
        path: '/pricing',
        name: 'pricing',
        builder: (context, state) => const PricingPage(),
      ),
      GoRoute(
        path: '/contact',
        name: 'contact',
        builder: (context, state) => const ContactPage(),
      ),
    ],
  );
});
