import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/website/presentation/pages/home_page.dart';

/// Routes for the Jobdun marketing site. One route — the home page — with
/// anchor-based section scrolling handled inside the page. The deep-link
/// pattern `jobdun.com.au/#how` is resolved by `HomePage` reading the
/// `Uri.fragment` on first build.
///
/// `/privacy` and `/delete-account` are NOT routed through Flutter; they
/// remain plain HTML in `site/` (faster first paint, no Flutter boot for
/// legal pages, Cloudflare Pages serves them directly).
final websiteRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => HomePage(initialFragment: state.uri.fragment),
      ),
    ],
  );
});
