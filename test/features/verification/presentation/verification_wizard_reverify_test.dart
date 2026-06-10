import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/auth/presentation/providers/auth_provider.dart';
import 'package:jobdun/features/verification/domain/entities/verification.dart';
import 'package:jobdun/features/verification/domain/entities/verification_document.dart'
    as docs;
import 'package:jobdun/features/verification/presentation/pages/verification_wizard_page.dart';
import 'package:jobdun/features/verification/presentation/providers/verification_provider.dart';
import 'package:jobdun/features/verification/presentation/providers/verifications_provider.dart';

// NOTE: these tests are written TDD-first and are intentionally UNRUN here —
// the orchestrator runs the full suite afterward (concurrent flutter builds
// corrupt .dart_tool). Style mirrors profile_completeness_test.dart.

// Fake auth controller — surfaces a fixed AuthState (role resolved) without
// touching Supabase or the role-resolver services.
class _FakeAuthController extends AuthController {
  _FakeAuthController(this._state);
  final AuthState _state;
  @override
  AuthState build() => _state;
}

// Fake verification controller — exposes a fixed document list (the realtime
// stream is never started) so the B5 pending guard can be exercised.
class _FakeVerificationController extends VerificationController {
  _FakeVerificationController(this._state);
  final VerificationState _state;
  @override
  VerificationState build() => _state;
}

Verification _verifiedAbn() => Verification(
  id: 'v1',
  userId: 'u1',
  kind: VerificationKind.abn,
  status: VerificationStatus.verified,
  manualFallbackAllowed: false,
  createdAt: DateTime(2026, 5, 1),
  updatedAt: DateTime(2026, 5, 1),
);

Verification _verifiedLicence() => Verification(
  id: 'v2',
  userId: 'u1',
  kind: VerificationKind.licence,
  status: VerificationStatus.verified,
  manualFallbackAllowed: false,
  createdAt: DateTime(2026, 5, 1),
  updatedAt: DateTime(2026, 5, 1),
);

docs.VerificationDocument _pendingLicenceDoc() => docs.VerificationDocument(
  id: 'd1',
  tradeId: 'u1',
  docType: docs.DocType.tradeLicence,
  filePath: 'u1/verification/trade_licence/x.jpg',
  status: docs.VerificationStatus.pending,
  submittedAt: DateTime(2026, 5, 20),
);

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
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  // Returns a router seeded with a /home base so the wizard is pushed onto a
  // navigation stack — `context.pop()` in the short-circuit paths then has
  // somewhere to land instead of asserting on an empty stack.
  ({Widget widget, GoRouter router}) harness({
    required bool reverify,
    required UserRole role,
    required List<Verification> verifs,
    List<docs.VerificationDocument> documents = const [],
  }) {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('home-marker')),
        ),
        GoRoute(
          path: '/wizard',
          builder: (_, _) => VerificationWizardPage(reverify: reverify),
        ),
      ],
    );
    final widget = ProviderScope(
      overrides: [
        currentUserIdSyncProvider.overrideWithValue('u1'),
        authControllerProvider.overrideWith(
          () => _FakeAuthController(
            AuthState(isAuthenticated: true, isRoleLoaded: true, role: role),
          ),
        ),
        verificationControllerProvider.overrideWith(
          () => _FakeVerificationController(
            VerificationState(documents: documents),
          ),
        ),
        verificationsForUserProvider('u1').overrideWith((ref) async => verifs),
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

  testWidgets('reverify==false on an already-verified builder short-circuits '
      '(shows snackbar, no intro)', (tester) async {
    final h = harness(
      reverify: false,
      role: UserRole.builder,
      verifs: [_verifiedAbn()],
    );
    await tester.pumpWidget(h.widget);
    h.router.push('/wizard');
    await tester.pump(); // build the wizard
    await tester.pump(); // resolve verifications future
    await tester.pump(); // post-frame short-circuit + pop
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text("You're already verified."), findsOneWidget);
    // The builder intro never renders — we short-circuited.
    expect(find.text('HOW WOULD YOU LIKE TO VERIFY?'), findsNothing);
  });

  testWidgets(
    'reverify==true on an already-verified builder does NOT short-circuit '
    '(intro renders, no snackbar)',
    (tester) async {
      final h = harness(
        reverify: true,
        role: UserRole.builder,
        verifs: [_verifiedAbn()],
      );
      await tester.pumpWidget(h.widget);
      h.router.push('/wizard');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text("You're already verified."), findsNothing);
      // The wizard stayed on the wizard route and rendered the builder intro
      // (the choose-how header only renders when we did NOT short-circuit).
      expect(find.text('HOW WOULD YOU LIKE TO VERIFY?'), findsOneWidget);
    },
  );

  testWidgets(
    'a trade with a pending licence doc sees the credentials list with the '
    'licence row "Under review" — no auto-opened sheet',
    (tester) async {
      final h = harness(
        reverify: false,
        role: UserRole.trade,
        verifs: const [],
        documents: [_pendingLicenceDoc()],
      );
      await tester.pumpWidget(h.widget);
      h.router.push('/wizard');
      await tester.pumpAndSettle();

      // The credentials list renders (not the old single-sheet flow).
      expect(find.text('Your credentials'), findsOneWidget);
      expect(find.textContaining('Under review'), findsWidgets);
      // The manual upload sheet (its title) must NOT have auto-opened.
      expect(find.text('Upload your trade licence'), findsNothing);
    },
  );

  testWidgets(
    'an already-verified trade is NOT short-circuited — the credentials list '
    'still renders so they can add other credentials',
    (tester) async {
      final h = harness(
        reverify: false,
        role: UserRole.trade,
        verifs: [_verifiedLicence()],
      );
      await tester.pumpWidget(h.widget);
      h.router.push('/wizard');
      await tester.pumpAndSettle();

      // No "already verified" pop — trades manage a multi-credential list now.
      expect(find.text("You're already verified."), findsNothing);
      expect(find.text('Your credentials'), findsOneWidget);
      expect(find.text('White Card'), findsOneWidget);
    },
  );
}
