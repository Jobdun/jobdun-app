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
// TODO(auth-flow-unification): rewrite the deleted "Path 2 — RoleSelectionSheet"
// test against OnboardingCompletionSheet. The new sheet is a 3-step PageView,
// not the legacy single-screen role picker, so the assertions need to step
// through role → name → avatar — different contract, separate test file.

void main() {
  setUpAll(() async {
    // dotenv is read at app boot; stub it so any indirect lookups don't throw.
    await dotenv.load(
      mergeWith: {
        'SUPABASE_URL': 'https://test.supabase.co',
        'SUPABASE_ANON_KEY': 'test_anon_key',
      },
    );
  });

  // The default flutter_test surface is too short — the new CTAs sit below
  // the fold. A 390×1800 dpr=1 surface matches the design width and gives
  // enough vertical room for taps to land on the CTAs.
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.physicalSize = const Size(390, 1800);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  // Real fonts (Archivo, Inter, Iconsax) don't load in widget tests, so the
  // Ahem fallback renders glyphs wider than production. That can trigger a
  // harmless RenderFlex overflow in tight rows on auth surfaces. Drain it
  // after each pump so the binding doesn't fail the test on the artifact.
  void drainKnownOverflow(WidgetTester tester) {
    final exc = tester.takeException();
    if (exc == null) return;
    if (exc.toString().contains('overflow')) return;
    throw exc;
  }

  // ── Minimal router covering only /login + /register?role=… ─────────────────
  GoRouter buildRouter({String initial = '/login'}) {
    return GoRouter(
      initialLocation: initial,
      routes: [
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
        // Forgot-password / phone-auth aren't exercised here but the login page
        // routes to them; provide stubs so navigation in production code does
        // not blow up if the test accidentally taps those links.
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
  // Note: the I'M HIRING / I'M LOOKING FOR WORK CTAs were moved off /login
  // and onto the FTUE carousel (slide 3) in the FTUE sprint. Their deep-link
  // contract is verified in test/features/ftue/ftue_flow_widget_test.dart.
  //
  // Path 1 — No-role fallback: /register without ?role= shows picker;
  //          tap-to-advance with no Continue button.
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('no-role fallback: tap-to-advance from picker, no Continue', (
    tester,
  ) async {
    final router = buildRouter(initial: '/register');
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    // Step-1 picker is visible.
    expect(find.text('WHICH SIDE ARE YOU ON?'), findsOneWidget);
    expect(find.text("I'M HIRING"), findsOneWidget);
    expect(find.text("I'M LOOKING FOR WORK"), findsOneWidget);

    // Critical: there should be NO "Continue" button — tap is the advance.
    expect(find.text('Continue'), findsNothing);
    expect(find.text('CONTINUE'), findsNothing);

    // Tap a card → step 2 form appears.
    await tester.tap(find.text("I'M HIRING"));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(find.text('WHICH SIDE ARE YOU ON?'), findsNothing);
    expect(find.text('CREATE ACCOUNT'), findsNWidgets(2));
    expect(find.text('HIRING'), findsOneWidget);
    expect(find.text('CHANGE'), findsOneWidget);
  });

  // Path 2 (formerly RoleSelectionSheet) — deleted with the role-only sheet.
  // The new OnboardingCompletionSheet is a 3-step PageView (role → name →
  // avatar) that needs its own dedicated test file; the assertions here no
  // longer correspond to live widgets.
}
