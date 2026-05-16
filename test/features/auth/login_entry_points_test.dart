import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/auth/domain/entities/user_role.dart';
import 'package:jobdun/features/auth/presentation/pages/login_page.dart';
import 'package:jobdun/features/auth/presentation/pages/register_page.dart';
import 'package:jobdun/features/ftue/data/geo_service.dart';
import 'package:jobdun/features/ftue/presentation/pages/ftue_page.dart';
import 'package:jobdun/features/ftue/presentation/providers/ftue_geo_provider.dart';

// Verifies every login-page entry point routes to the right destination:
// - Email submit (covered by auth_test/sign_in usecase tests, not here)
// - Google SSO (auth provider — out of scope for routing assertions)
// - Apple SSO (auth provider — out of scope for routing assertions)
// - Continue with phone → /phone-auth
// - Create account → /ftue?from=login (the missing-link fix)
// - Forgot password? → /forgot-password
//
// Pre-Supabase init is not required here; nothing in these tests touches
// the auth controller's network path.

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
    // Tall surface so the legal footer + create-account row are mounted
    // even when Ahem-font glyphs render wider than production Inter.
    binding.platformDispatcher.views.first.physicalSize = const Size(390, 1800);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  GoRouter buildRouter({String initial = '/login'}) {
    return GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
        GoRoute(
          path: '/ftue',
          builder: (context, state) {
            final fromLogin = state.uri.queryParameters['from'] == 'login';
            return FtuePage(fromLogin: fromLogin);
          },
        ),
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

  Widget wrap(GoRouter router) {
    return ProviderScope(
      // FTUE's geo provider would otherwise call ipapi.co under test —
      // stub to the non-AU outcome so slide 2 renders generic copy and
      // no real HTTP call leaks out.
      overrides: [geoServiceProvider.overrideWithValue(_NoOpGeoService())],
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

  // Drain the FTUE's missing-asset errors after any pump that mounts
  // /ftue. The wow-pass slides precache hero photos that aren't checked in
  // yet; FtueHeroPhoto.errorBuilder renders a navy placeholder, so this is
  // documented graceful degradation — just keep the binding from failing
  // the test on it.
  void drainAssetErrors(WidgetTester tester) {
    while (true) {
      final exc = tester.takeException();
      if (exc == null) return;
      final msg = exc.toString();
      if (msg.contains('Unable to load asset') ||
          msg.contains('image failed to precache') ||
          msg.contains('Multiple exceptions')) {
        continue;
      }
      throw exc;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Create account → /ftue?from=login (the missing-link fix)
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('Create account link routes to /ftue?from=login', (tester) async {
    final router = buildRouter();
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();

    final link = find.byKey(const Key('login.create_account_link'));
    expect(link, findsOneWidget);

    await tester.ensureVisible(link);
    await tester.pumpAndSettle();

    await tester.tap(link, warnIfMissed: false);
    await tester.pumpAndSettle();
    // Once routing lands on /ftue, the hero-photo precache fires its known
    // missing-asset errors — drain them so the binding doesn't fail.
    drainAssetErrors(tester);

    expect(router.state.uri.toString(), '/ftue?from=login');
  });

  // ───────────────────────────────────────────────────────────────────────────
  // FTUE behaviour when arrived from /login:
  //   - Slide 1 shows back arrow → tapping returns to /login
  //   - Slide 3 hides the "I already have an account · LOG IN" link
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('FTUE from /login: slide 1 back arrow returns to /login', (
    tester,
  ) async {
    final router = buildRouter(initial: '/ftue?from=login');
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();
    drainAssetErrors(tester);

    // Back arrow has the "Back to log in." semantics label.
    final back = find.bySemanticsLabel('Back to log in.');
    expect(back, findsOneWidget);

    await tester.tap(back, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/login');
  });

  testWidgets(
    'FTUE from /login: slide 3 hides "I already have an account" link',
    (tester) async {
      final router = buildRouter(initial: '/ftue?from=login');
      await tester.pumpWidget(wrap(router));
      await tester.pumpAndSettle();
      drainAssetErrors(tester);

      // jumpToPage(2) is more deterministic than flinging through pages —
      // the new wow-pass slide layout uses SingleChildScrollView and a
      // single -400px fling can overshoot to slide 3 when content is tall.
      final pageView = tester.widget<PageView>(find.byType(PageView));
      pageView.controller!.jumpToPage(2);
      await tester.pumpAndSettle();
      drainAssetErrors(tester);

      // Both CTAs render.
      expect(find.text("I'M HIRING"), findsOneWidget);
      expect(find.text("I'M LOOKING FOR WORK"), findsOneWidget);
      // The redundant login link must not appear — the user just came from
      // /login, rendering it would just send them back in a loop.
      expect(find.text('I already have an account'), findsNothing);
      expect(find.text('LOG IN'), findsNothing);
    },
  );

  // ───────────────────────────────────────────────────────────────────────────
  // Phone icon → /phone-auth
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('Phone icon routes to /phone-auth', (tester) async {
    final router = buildRouter();
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();

    final phone = find.byKey(const Key('login.sso.phone'));
    expect(phone, findsOneWidget);

    await tester.ensureVisible(phone);
    await tester.pumpAndSettle();

    await tester.tap(phone, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/phone-auth');
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Forgot password? → /forgot-password
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('Forgot? link routes to /forgot-password', (tester) async {
    final router = buildRouter();
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();

    final forgot = find.text('Forgot?');
    expect(forgot, findsOneWidget);

    await tester.tap(forgot, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/forgot-password');
  });

  // ───────────────────────────────────────────────────────────────────────────
  // SSO entry points are interactive icon tiles (not plain text labels) —
  // the second of the three problems called out in the brief.
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('Google, Apple, Phone render as tappable icon tiles', (
    tester,
  ) async {
    final router = buildRouter();
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login.sso.google')), findsOneWidget);
    expect(find.byKey(const Key('login.sso.apple')), findsOneWidget);
    expect(find.byKey(const Key('login.sso.phone')), findsOneWidget);

    // All three are icon-only — no visible captions. Screen readers get the
    // accessible name via the SocialAuthButton's Semantics wrapper.
    expect(find.text('Phone'), findsNothing);
    expect(find.text('Google'), findsNothing);
    expect(find.text('Apple'), findsNothing);
  });
}

/// Stub that fails the lookup with the non-AU outcome — keeps slide 2 on
/// the generic copy path with zero network traffic.
class _NoOpGeoService implements GeoService {
  @override
  Future<GeoLookupOutcome> lookup() async =>
      GeoLookupOutcome.failure(GeoFailureReason.nonAu, 0);
}
