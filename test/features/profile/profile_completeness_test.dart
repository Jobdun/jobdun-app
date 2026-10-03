import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/services/ftue_service.dart';
import 'package:jobdun/features/auth/presentation/providers/auth_provider.dart';
import 'package:jobdun/features/home/presentation/widgets/profile_completeness_banner.dart';
import 'package:jobdun/features/profile/domain/entities/builder_profile.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';
import 'package:jobdun/features/profile/domain/entities/user_profile.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';

// Minimal fake — sidesteps Supabase by never building the real datasource
// and only ever surfacing whatever ProfileState the test supplies.
class _FakeProfileController extends ProfileController {
  _FakeProfileController(this._initial);
  final ProfileState _initial;

  @override
  ProfileState build() => _initial;
}

class _RoleController extends AuthController {
  _RoleController(this.role);
  final UserRole? role;

  @override
  AuthState build() =>
      AuthState(isAuthenticated: true, isRoleLoaded: true, role: role);
}

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
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  void drainKnownOverflow(WidgetTester tester) {
    final exc = tester.takeException();
    if (exc == null) return;
    if (exc.toString().contains('overflow')) return;
    throw exc;
  }

  // Tiny harness — drops the banner under a router that knows /profile/edit
  // so the CTA tap can be observed via router.state.uri.
  ({Widget widget, GoRouter router}) buildHarness(
    ProfileState state, {
    UserRole? role,
    bool roleUnknown = false,
    String? messageOverride,
  }) {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => Scaffold(
            body: SafeArea(
              child: ProfileCompletenessBanner(
                messageOverride: messageOverride,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/profile/edit',
          builder: (_, _) => const Scaffold(body: Text('edit-page-marker')),
        ),
      ],
    );
    final widget = ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => _RoleController(
            roleUnknown
                ? null
                : role ??
                      (state.tradeProfile != null
                          ? UserRole.trade
                          : UserRole.builder),
          ),
        ),
        profileControllerProvider.overrideWith(
          () => _FakeProfileController(state),
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
    return (widget: widget, router: router);
  }

  // Builder ProfileState — half the required fields filled (50%).
  ProfileState builderHalfDone() {
    return ProfileState(
      profile: const UserProfile(id: 'u1'),
      builderProfile: const BuilderProfile(
        id: 'u1',
        companyName: 'Acme Co',
        abn: '12345678901',
        // service_suburb missing, phone unverified → 50%
      ),
    );
  }

  // Builder ProfileState — every required field filled (100%).
  ProfileState builderFullyDone() {
    return ProfileState(
      profile: UserProfile(id: 'u1', phoneVerifiedAt: DateTime(2026, 5, 14)),
      builderProfile: const BuilderProfile(
        id: 'u1',
        companyName: 'Acme Co',
        abn: '12345678901',
        serviceSuburb: 'Parramatta',
      ),
    );
  }

  // Trade ProfileState — every required field filled (100%).
  ProfileState tradeFullyDone() {
    return ProfileState(
      profile: UserProfile(id: 'u1', phoneVerifiedAt: DateTime(2026, 5, 14)),
      tradeProfile: const TradeProfile(
        id: 'u1',
        fullName: 'Jane Doe',
        primaryTrade: 'electrician',
        baseSuburb: 'Bondi',
        licenceUrl: 'private-docs/u1/licence.pdf',
        portfolioUrls: ['url1', 'url2'],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Banner renders when below 100% and shows the correct %
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('builder at 50% shows banner with 50% label', (tester) async {
    final h = buildHarness(builderHalfDone());
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(find.text('Complete your profile'), findsOneWidget);
    // The Figma card (node 80:4251) drops the visible "50%" — the progress bar
    // carries the figure, and the number stays available to screen readers on
    // the bar's semantics node.
    expect(find.bySemanticsLabel('50 percent complete'), findsOneWidget);
    expect(
      find.text('Add a few details to build trust and get applicants'),
      findsOneWidget,
    );
  });

  testWidgets('trade banner describes getting work, not applicants', (
    tester,
  ) async {
    final h = buildHarness(
      const ProfileState(
        profile: UserProfile(id: 'u1'),
        tradeProfile: TradeProfile(
          id: 'u1',
          fullName: 'Test Trade',
          primaryTrade: 'electrician',
        ),
      ),
      role: UserRole.trade,
    );
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();

    expect(
      find.text('Add a few details to build trust and get more work'),
      findsOneWidget,
    );
    expect(find.textContaining('applicants'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown role banner uses neutral copy', (tester) async {
    final h = buildHarness(builderHalfDone(), roleUnknown: true);
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();

    expect(find.text('Add a few details to build trust'), findsOneWidget);
    expect(find.textContaining('applicants'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final role in [UserRole.builder, UserRole.trade, null]) {
    testWidgets('message override takes priority for $role', (tester) async {
      final h = buildHarness(
        builderHalfDone(),
        role: role,
        roleUnknown: role == null,
        messageOverride: 'Add your phone number',
      );
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      expect(find.text('Add your phone number'), findsOneWidget);
      expect(find.textContaining('Add a few details'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Banner hides at 100% (builder)
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('builder at 100% hides the banner entirely', (tester) async {
    final h = buildHarness(builderFullyDone());
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(find.text('Complete your profile'), findsNothing);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Banner hides at 100% (trade — 5 fields × 20%)
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('trade at 100% hides the banner entirely', (tester) async {
    final h = buildHarness(tradeFullyDone());
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(find.text('Complete your profile'), findsNothing);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Trade weighting: licence_url present moves the % by exactly 20.
  // ───────────────────────────────────────────────────────────────────────────
  test('trade licence_url presence is worth 20% in the calc', () {
    final base = ProfileState(
      profile: const UserProfile(id: 'u1'),
      tradeProfile: const TradeProfile(
        id: 'u1',
        fullName: 'x',
        primaryTrade: 'electrician',
        baseSuburb: 'Bondi',
      ),
    );
    final withLicence = ProfileState(
      profile: const UserProfile(id: 'u1'),
      tradeProfile: const TradeProfile(
        id: 'u1',
        fullName: 'x',
        primaryTrade: 'electrician',
        baseSuburb: 'Bondi',
        licenceUrl: 'private-docs/u1/licence.pdf',
      ),
    );
    expect(
      withLicence.profileCompletenessPct - base.profileCompletenessPct,
      20,
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Dismiss hides the banner for the rest of the run
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('tapping dismiss hides the banner for the session', (
    tester,
  ) async {
    final h = buildHarness(builderHalfDone());
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(find.text('Complete your profile'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Dismiss'));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(find.text('Complete your profile'), findsNothing);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // CTA tap routes to /profile/edit
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('tapping the banner body routes to /profile/edit', (
    tester,
  ) async {
    final h = buildHarness(builderHalfDone());
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    await tester.tap(find.text('Complete your profile'));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(h.router.state.uri.toString(), '/profile/edit');
    expect(find.text('edit-page-marker'), findsOneWidget);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // FtueService.hasSeenFirstHomeToast persists across reads
  // ───────────────────────────────────────────────────────────────────────────
  test('first-home toast flag flips to true after markSeen', () async {
    expect(await FtueService.hasSeenFirstHomeToast(), isFalse);
    await FtueService.markFirstHomeToastSeen();
    expect(await FtueService.hasSeenFirstHomeToast(), isTrue);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // FtueService.resetFtue clears every onboarding flag, including the toast
  // ───────────────────────────────────────────────────────────────────────────
  test('resetFtue clears the first-home toast flag', () async {
    await FtueService.markFirstHomeToastSeen();
    expect(await FtueService.hasSeenFirstHomeToast(), isTrue);
    await FtueService.resetFtue();
    expect(await FtueService.hasSeenFirstHomeToast(), isFalse);
  });
  testWidgets('trade ignores an empty builder row when scoring completion', (
    tester,
  ) async {
    final h = buildHarness(
      const ProfileState(
        profile: UserProfile(id: 'u1'),
        builderProfile: BuilderProfile(id: 'u1', companyName: ''),
        tradeProfile: TradeProfile(
          id: 'u1',
          fullName: 'Test Trade',
          primaryTrade: 'electrician',
          baseSuburb: 'Sydney',
          portfolioUrls: ['photo'],
        ),
      ),
      role: UserRole.trade,
    );
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('60 percent complete'), findsOneWidget);
    expect(find.bySemanticsLabel('0 percent complete'), findsNothing);
  });

  testWidgets('builder ignores a populated trade row when scoring completion', (
    tester,
  ) async {
    final h = buildHarness(
      const ProfileState(
        profile: UserProfile(id: 'u1'),
        builderProfile: BuilderProfile(id: 'u1', companyName: 'Test Company'),
        tradeProfile: TradeProfile(
          id: 'u1',
          fullName: 'Test Trade',
          primaryTrade: 'electrician',
          baseSuburb: 'Sydney',
          portfolioUrls: ['photo'],
        ),
      ),
      role: UserRole.builder,
    );
    await tester.pumpWidget(h.widget);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('25 percent complete'), findsOneWidget);
  });
}
