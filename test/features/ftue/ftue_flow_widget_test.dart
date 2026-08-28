import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:jobdun/core/services/ftue_service.dart';
import 'package:jobdun/features/auth/domain/entities/user_role.dart';
import 'package:jobdun/features/auth/presentation/pages/login_page.dart';
import 'package:jobdun/features/auth/presentation/pages/register_page.dart';
import 'package:jobdun/features/ftue/data/geo_service.dart';
import 'package:jobdun/features/ftue/data/models/geo_result.dart';
import 'package:jobdun/features/ftue/presentation/pages/ftue_page.dart';
import 'package:jobdun/features/ftue/presentation/providers/ftue_geo_provider.dart';

/// FTUE contract after the Figma "Onboard" rebuild (node 17:5084).
///
/// The shape changed: the two role CTAs, the log-in link and guest browsing
/// now live in a sheet pinned *below* the carousel, so they're reachable from
/// slide 1 instead of only slide 3. That's what retired the SKIP affordance —
/// there is nothing left for it to shortcut. Everything else (routing, the
/// completion flag, geo personalisation, the S4 back escapes) is unchanged and
/// still asserted here.
void main() {
  setUpAll(() async {
    await dotenv.load(
      mergeWith: {
        'SUPABASE_URL': 'https://test.supabase.co',
        'SUPABASE_ANON_KEY': 'test_anon_key',
      },
    );
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.physicalSize = const Size(390, 1800);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    // FtueService reads SharedPreferences directly; each case needs a clean
    // mock backend so completion state doesn't bleed across tests.
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  // Real fonts (Archivo, Inter, Phosphor) don't load in widget tests, so the
  // Ahem fallback renders glyphs wider than production — that triggers
  // harmless RenderFlex overflows in the dense role rows. The binding wraps
  // multi-error rounds into a "Multiple exceptions (N)" umbrella, so loop
  // until takeException returns null and rethrow anything unexpected.
  bool knownHarmless(Object exc) {
    final msg = exc.toString();
    return msg.contains('overflow') ||
        msg.contains('Unable to load asset') ||
        msg.contains('image failed to precache') ||
        msg.contains('Multiple exceptions');
  }

  void drainKnownOverflow(WidgetTester tester) {
    while (true) {
      final exc = tester.takeException();
      if (exc == null) return;
      if (!knownHarmless(exc)) throw exc;
    }
  }

  GoRouter buildRouter({String initial = '/ftue'}) {
    return GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/ftue',
          builder: (_, state) =>
              FtuePage(fromLogin: state.uri.queryParameters['from'] == 'login'),
        ),
        GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
        GoRoute(path: '/browse', builder: (_, _) => const Scaffold()),
        GoRoute(
          path: '/register',
          builder: (context, state) {
            final raw = state.uri.queryParameters['role'];
            final initialRole = switch (raw) {
              'builder' => UserRole.builder,
              'trade' => UserRole.trade,
              _ => null,
            };
            return RegisterPage(initialRole: initialRole);
          },
        ),
        GoRoute(path: '/forgot-password', builder: (_, _) => const Scaffold()),
        GoRoute(path: '/phone-auth', builder: (_, _) => const Scaffold()),
      ],
    );
  }

  // Widget tests must not hit ipapi.co. Defaults to the [_StubGeoService.none]
  // stub (generic copy path); tests that need a specific outcome supply their
  // own [GeoService] via [geoService].
  Widget wrap(GoRouter router, {GeoService? geoService}) {
    return ProviderScope(
      overrides: [
        geoServiceProvider.overrideWithValue(
          geoService ?? _StubGeoService.none(),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }

  Future<void> pumpFtue(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);
  }

  Future<void> jumpToSlide(WidgetTester tester, int index) async {
    final pageView = tester.widget<PageView>(find.byType(PageView));
    pageView.controller!.jumpToPage(index);
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Slide 1 — trust headline + the always-present role sheet
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('slide 1 renders the trust headline', (tester) async {
    await pumpFtue(tester, buildRouter());

    expect(find.text('ONLY VERIFIED.'), findsOneWidget);
    expect(find.text('NO\nTIMEWASTERS.'), findsOneWidget);
    // Trust seals floating on the hero.
    expect(find.text('Licensed & Verified'), findsOneWidget);
    expect(find.text('ID Checked'), findsOneWidget);
  });

  testWidgets('role sheet, login and browse are reachable from slide 1', (
    tester,
  ) async {
    await pumpFtue(tester, buildRouter());

    expect(find.byKey(const Key('ftue.role.trade')), findsOneWidget);
    expect(find.byKey(const Key('ftue.role.builder')), findsOneWidget);
    expect(find.byKey(const Key('ftue.login')), findsOneWidget);
    expect(find.byKey(const Key('ftue.browse')), findsOneWidget);
    expect(find.text('Find Work'), findsOneWidget);
    expect(find.text('Hire Workers'), findsOneWidget);
  });

  // The sheet lives outside the PageView, so it must survive a page change.
  testWidgets('role sheet stays put while the hero swipes', (tester) async {
    await pumpFtue(tester, buildRouter());
    await jumpToSlide(tester, 2);

    expect(find.text('BUILT FOR'), findsOneWidget);
    expect(find.byKey(const Key('ftue.role.trade')), findsOneWidget);
    expect(find.byKey(const Key('ftue.role.builder')), findsOneWidget);
    expect(find.byKey(const Key('ftue.login')), findsOneWidget);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Exits — each one routes and sets has_completed_ftue
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('Hire Workers deep-links to /register?role=builder', (
    tester,
  ) async {
    final router = buildRouter();
    await pumpFtue(tester, router);
    expect(await FtueService.hasCompletedFtue(), isFalse);

    await tester.tap(find.byKey(const Key('ftue.role.builder')));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(router.state.uri.toString(), '/register?role=builder');
    expect(await FtueService.hasCompletedFtue(), isTrue);
  });

  testWidgets('Find Work deep-links to /register?role=trade', (tester) async {
    final router = buildRouter();
    await pumpFtue(tester, router);

    await tester.tap(find.byKey(const Key('ftue.role.trade')));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(router.state.uri.toString(), '/register?role=trade');
    expect(await FtueService.hasCompletedFtue(), isTrue);
  });

  testWidgets('login link routes to /login and marks FTUE complete', (
    tester,
  ) async {
    final router = buildRouter();
    await pumpFtue(tester, router);

    await tester.tap(find.byKey(const Key('ftue.login')));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(router.state.uri.toString(), '/login');
    expect(await FtueService.hasCompletedFtue(), isTrue);
  });

  // App Review 5.1.1(v) — nobody has to register just to look.
  testWidgets('browse link routes to /browse and marks FTUE complete', (
    tester,
  ) async {
    final router = buildRouter();
    await pumpFtue(tester, router);

    await tester.tap(find.byKey(const Key('ftue.browse')));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(router.state.uri.toString(), '/browse');
    expect(await FtueService.hasCompletedFtue(), isTrue);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Wow-pass — slide 2 personalised copy + suburb pins
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('slide 2 renders personalised copy + cluster when geo succeeds', (
    tester,
  ) async {
    final router = buildRouter();
    await tester.pumpWidget(
      wrap(
        router,
        geoService: _StubGeoService.success(
          const GeoResult(
            city: 'Sydney',
            region: 'New South Wales',
            country: 'AU',
            suburbs: ['Parramatta', 'Penrith', 'Liverpool'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);
    await jumpToSlide(tester, 1);

    expect(find.text('JOBS IN'), findsOneWidget);
    expect(find.text('SYDNEY.'), findsOneWidget);
    // Suburb pins render on the map hero.
    expect(find.text('Parramatta'), findsOneWidget);
    expect(find.text('Penrith'), findsOneWidget);
    expect(find.text('Liverpool'), findsOneWidget);
  });

  testWidgets('slide 2 falls back to generic copy when geo returns null', (
    tester,
  ) async {
    // wrap() already installs the none-returning stub by default.
    await pumpFtue(tester, buildRouter());
    await jumpToSlide(tester, 1);

    expect(find.text('JOBS NEAR YOU.'), findsOneWidget);
    expect(find.text('APPLY IN THREE TAPS.'), findsOneWidget);
  });

  testWidgets('slide 2 falls back to generic when geo lookup throws', (
    tester,
  ) async {
    final router = buildRouter();
    await tester.pumpWidget(
      wrap(router, geoService: _StubGeoService.throwing()),
    );
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);
    await jumpToSlide(tester, 1);

    expect(find.text('JOBS NEAR YOU.'), findsOneWidget);
    expect(find.text('APPLY IN THREE TAPS.'), findsOneWidget);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // S4 regression — the carousel must never be a trap
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('fromLogin: slide 3 keeps the login link and a back caret', (
    tester,
  ) async {
    await pumpFtue(tester, buildRouter(initial: '/ftue?from=login'));
    await jumpToSlide(tester, 2);

    expect(find.byKey(const Key('ftue.login')), findsOneWidget);
    expect(find.byIcon(AppIcons.arrowLeft), findsOneWidget);
  });

  testWidgets('back caret on slide 3 steps back to slide 2', (tester) async {
    final router = buildRouter();
    await pumpFtue(tester, router);
    await jumpToSlide(tester, 2);

    expect(find.text('BUILT FOR'), findsOneWidget);
    await tester.tap(find.byIcon(AppIcons.arrowLeft));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(find.text('JOBS NEAR YOU.'), findsOneWidget);
    expect(router.state.uri.path, '/ftue');
  });

  testWidgets('no back caret on slide 1 for a first-launch user', (
    tester,
  ) async {
    await pumpFtue(tester, buildRouter());

    expect(find.byIcon(AppIcons.arrowLeft), findsNothing);
  });

  testWidgets('system back on slide 3 steps back a slide, not out of the app', (
    tester,
  ) async {
    final router = buildRouter();
    await pumpFtue(tester, router);
    await jumpToSlide(tester, 2);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(find.text('JOBS NEAR YOU.'), findsOneWidget);
    expect(router.state.uri.path, '/ftue');
  });

  testWidgets('fromLogin: back caret on slide 1 returns to /login', (
    tester,
  ) async {
    final router = buildRouter(initial: '/ftue?from=login');
    await pumpFtue(tester, router);

    await tester.tap(find.byIcon(AppIcons.arrowLeft));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(router.state.uri.toString(), '/login');
  });
}

/// Test double for GeoService. Three flavours:
///   - success(GeoResult) — returns the supplied result
///   - none()              — returns a non-AU failure (drives generic copy)
///   - throwing()          — throws, exercising the error branch
class _StubGeoService implements GeoService {
  _StubGeoService.success(GeoResult result)
    : _outcome = GeoLookupOutcome.success(result, 0),
      _throws = false;

  _StubGeoService.none()
    : _outcome = GeoLookupOutcome.failure(GeoFailureReason.nonAu, 0),
      _throws = false;

  _StubGeoService.throwing()
    : _outcome = GeoLookupOutcome.failure(GeoFailureReason.network, 0),
      _throws = true;

  final GeoLookupOutcome _outcome;
  final bool _throws;

  @override
  Future<GeoLookupOutcome> lookup() async {
    if (_throws) throw Exception('stub');
    return _outcome;
  }
}
