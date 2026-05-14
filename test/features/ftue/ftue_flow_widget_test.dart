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
import 'package:jobdun/features/ftue/presentation/pages/ftue_page.dart';

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
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  // Real fonts (Oswald, Iconsax) don't load in widget tests so the Ahem
  // fallback renders glyphs wider than production. That triggers harmless
  // RenderFlex overflows in dense rows. Drain them after each pump so the
  // binding doesn't fail the test on the known artifact.
  void drainKnownOverflow(WidgetTester tester) {
    final exc = tester.takeException();
    if (exc == null) return;
    if (exc.toString().contains('overflow')) return;
    throw exc;
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
  // Slide 1 — renders trust copy + SKIP affordance
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('slide 1 renders trust headline + SKIP visible', (tester) async {
    final router = buildRouter();
    await tester.pumpWidget(wrap(router));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(find.text('VERIFIED TRADIES.'), findsOneWidget);
    expect(find.text('REAL JOBS.'), findsOneWidget);
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
}
