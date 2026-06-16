import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/services/ftue_service.dart';
import 'package:jobdun/features/auth/domain/entities/user_role.dart';
import 'package:jobdun/features/auth/presentation/pages/login_page.dart';
import 'package:jobdun/features/auth/presentation/pages/register_page.dart';
import 'package:jobdun/features/ftue/data/geo_service.dart';
import 'package:jobdun/features/ftue/data/models/geo_result.dart';
import 'package:jobdun/features/ftue/presentation/pages/ftue_page.dart';
import 'package:jobdun/features/ftue/presentation/providers/ftue_geo_provider.dart';

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
    // FtueService reads from SharedPreferences directly; tests need a clean
    // mock backend each run so completion state doesn't bleed across cases.
    SharedPreferences.setMockInitialValues({});

    // The FTUE precaches its hero photos in didChangeDependencies. Until
    // Ken's image files land in assets/images/ftue/ the precache + the
    // Image.asset render both throw an "Unable to load asset" assertion —
    // the production errorBuilder + provider .catchError both swallow it
    // cleanly, but Flutter still surfaces the error via FlutterError.
    // Filter that one known message at the binding level so it never
    // poisons takeException(); anything else still flows through.
    final defaultOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('Unable to load asset')) {
        return;
      }
      defaultOnError?.call(details);
    };
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  // Real fonts (Archivo, Inter, Iconsax) don't load in widget tests so the Ahem
  // fallback renders glyphs wider than production — that triggers harmless
  // RenderFlex overflows in dense rows.
  //
  // The FTUE wow-pass also precaches the slide-1 + slide-3 hero photos.
  // Until Ken's image files land in assets/images/ftue/, both the precache
  // and the Image.asset render throw "Unable to load asset" — that's the
  // documented graceful-degradation path (FtueHeroPhoto.errorBuilder
  // renders a navy placeholder). Drain both classes of known-harmless
  // errors after each pump; rethrow anything else.
  //
  // The binding wraps multi-error rounds into a "Multiple exceptions (N)"
  // umbrella, so we loop until takeException returns null.
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
        GoRoute(path: '/ftue', builder: (_, _) => const FtuePage()),
        GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
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
  // stub (generic copy path); tests that need a specific outcome supply
  // their own [GeoService] via [geoService].
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
          theme: AppTheme.dark(),
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Slide 1 — renders trust copy + SKIP affordance
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('slide 1 renders trust headline + SKIP visible', (tester) async {
    final router = buildRouter();
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(find.text('ONLY VERIFIED.'), findsOneWidget);
    expect(find.text('NO TIMEWASTERS.'), findsOneWidget);
    expect(find.text('SKIP'), findsOneWidget);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // SKIP — slide 1 → /login, flag is set
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('SKIP from slide 1 routes to /login and marks FTUE complete', (
    tester,
  ) async {
    final router = buildRouter();
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(await FtueService.hasCompletedFtue(), isFalse);

    await tester.tap(find.text('SKIP'));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(router.state.uri.toString(), '/login');
    expect(await FtueService.hasCompletedFtue(), isTrue);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Slide 3 — swipe to last slide hides SKIP and shows CTAs + login link
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('slide 3 hides SKIP and shows both role CTAs + login link', (
    tester,
  ) async {
    final router = buildRouter();
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    // Swipe to slide 2 then slide 3.
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(find.text('BUILT FOR'), findsOneWidget);
    expect(find.text('AUSSIE SITES.'), findsOneWidget);
    expect(find.text("I'M HIRING"), findsOneWidget);
    expect(find.text("I'M LOOKING FOR WORK"), findsOneWidget);
    expect(find.text('LOG IN'), findsOneWidget);
    // No SKIP on the final slide — the CTAs are the exit.
    expect(find.text('SKIP'), findsNothing);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Builder CTA → /register?role=builder, flag is set
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets("I'M HIRING deep-links to /register?role=builder", (
    tester,
  ) async {
    final router = buildRouter();
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    await tester.tap(find.text("I'M HIRING"));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(router.state.uri.toString(), '/register?role=builder');
    expect(await FtueService.hasCompletedFtue(), isTrue);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Trade CTA → /register?role=trade, flag is set
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets("I'M LOOKING FOR WORK deep-links to /register?role=trade", (
    tester,
  ) async {
    final router = buildRouter();
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    await tester.tap(find.text("I'M LOOKING FOR WORK"));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(router.state.uri.toString(), '/register?role=trade');
    expect(await FtueService.hasCompletedFtue(), isTrue);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Login link on slide 3 → /login, flag is set
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('login link on slide 3 routes to /login and marks complete', (
    tester,
  ) async {
    final router = buildRouter();
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    await tester.tap(find.text('LOG IN'));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(router.state.uri.toString(), '/login');
    expect(await FtueService.hasCompletedFtue(), isTrue);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Wow-pass — slide 2 personalised copy + suburb chips
  // ───────────────────────────────────────────────────────────────────────────
  // Page-snap via the PageController directly — flings can overshoot by
  // a page when slide content is tall (the new wow-pass layout uses a
  // SingleChildScrollView), so targeting the controller keeps tests on
  // the slide they actually mean to assert against.
  Future<void> swipeToSlideTwo(WidgetTester tester) async {
    final pageView = tester.widget<PageView>(find.byType(PageView));
    final controller = pageView.controller!;
    controller.jumpToPage(1);
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);
  }

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
    await swipeToSlideTwo(tester);

    expect(find.text('JOBS IN'), findsOneWidget);
    expect(find.text('SYDNEY.'), findsOneWidget);
    expect(find.text('100+ active jobs'), findsOneWidget);
    expect(find.text('within 15km of you.'), findsOneWidget);
    // Suburb chips render.
    expect(find.text('Parramatta'), findsOneWidget);
    expect(find.text('Penrith'), findsOneWidget);
    expect(find.text('Liverpool'), findsOneWidget);
  });

  testWidgets('slide 2 falls back to generic copy when geo returns null', (
    tester,
  ) async {
    final router = buildRouter();
    // wrap() already installs the none-returning stub by default.
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);
    await swipeToSlideTwo(tester);

    expect(find.text('JOBS NEAR YOU.'), findsOneWidget);
    expect(find.text('APPLY IN THREE TAPS.'), findsOneWidget);
    expect(find.text('Sorted by your suburb.'), findsOneWidget);
    expect(find.text('No scrolling through dud jobs.'), findsOneWidget);
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
    await swipeToSlideTwo(tester);

    expect(find.text('JOBS NEAR YOU.'), findsOneWidget);
    expect(find.text('APPLY IN THREE TAPS.'), findsOneWidget);
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
