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
import 'package:jobdun/features/ftue/presentation/pages/ftue_page.dart';

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

      // Swipe to slide 2 then slide 3.
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

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

    // Only Phone shows a visible caption — Google + Apple use Semantics for
    // screen readers but no visible label (Jakob's Law: brand marks are
    // universally recognised). Phone keeps its caption for AU tradie
    // OTP-path discoverability.
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Google'), findsNothing);
    expect(find.text('Apple'), findsNothing);
  });
}
