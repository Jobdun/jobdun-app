import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/auth/presentation/providers/auth_provider.dart';
import 'package:jobdun/features/verification/domain/entities/verification.dart'
    show Verification;
import 'package:jobdun/features/verification/presentation/pages/verification_wizard_page.dart';
import 'package:jobdun/features/verification/presentation/providers/verification_provider.dart';
import 'package:jobdun/features/verification/presentation/providers/verifications_provider.dart';

// New trade behaviour: the wizard lands on a "Your credentials" list (licence +
// White Card + public liability) instead of force-opening a single licence
// sheet. Nothing is auto-opened; nothing short-circuits.
class _FakeAuthController extends AuthController {
  _FakeAuthController(this._state);
  final AuthState _state;
  @override
  AuthState build() => _state;
}

class _FakeVerificationController extends VerificationController {
  _FakeVerificationController(this._state);
  final VerificationState _state;
  @override
  VerificationState build() => _state;
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
    binding.platformDispatcher.views.first.physicalSize = const Size(390, 2400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  ({Widget widget, GoRouter router}) harness() {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('home-marker')),
        ),
        GoRoute(
          path: '/wizard',
          builder: (_, _) => const VerificationWizardPage(),
        ),
      ],
    );
    final widget = ProviderScope(
      overrides: [
        currentUserIdSyncProvider.overrideWithValue('u1'),
        authControllerProvider.overrideWith(
          () => _FakeAuthController(
            const AuthState(
              isAuthenticated: true,
              isRoleLoaded: true,
              role: UserRole.trade,
            ),
          ),
        ),
        verificationControllerProvider.overrideWith(
          () => _FakeVerificationController(const VerificationState()),
        ),
        verificationsForUserProvider(
          'u1',
        ).overrideWith((ref) async => <Verification>[]),
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

  testWidgets('a trade lands on the credentials list with all three rows', (
    tester,
  ) async {
    final h = harness();
    await tester.pumpWidget(h.widget);
    h.router.push('/wizard');
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Your credentials'), findsOneWidget);
    expect(find.text('Trade licence'), findsOneWidget);
    expect(find.text('White Card'), findsOneWidget);
    expect(find.text('Public liability'), findsOneWidget);
  });

  testWidgets(
    'U3: the hub leads with the payoff preview and a progress count',
    (tester) async {
      final h = harness();
      await tester.pumpWidget(h.widget);
      h.router.push('/wizard');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // App bar names the hub, not a wizard.
      expect(find.text('Credentials'), findsOneWidget);
      // "How builders see you" strip with ghost chips + caption.
      expect(find.text('HOW BUILDERS SEE YOU'), findsOneWidget);
      expect(find.text('LICENCE'), findsOneWidget);
      expect(find.text('INSURED'), findsOneWidget);
      // Nothing added yet for this fresh trade.
      expect(find.text('0 OF 3 ADDED'), findsOneWidget);
    },
  );

  testWidgets('a trade is NOT auto-popped and no upload sheet opens itself', (
    tester,
  ) async {
    final h = harness();
    await tester.pumpWidget(h.widget);
    h.router.push('/wizard');
    await tester.pumpAndSettle();

    // The wizard stayed put (the old flow auto-popped after the sheet) — its
    // credentials heading is still on screen.
    expect(find.text('Your credentials'), findsOneWidget);
    // The manual sheet (its title) did not auto-open.
    expect(find.text('Upload your trade licence'), findsNothing);
  });
}
