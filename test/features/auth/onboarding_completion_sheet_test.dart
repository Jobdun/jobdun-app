import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/auth/presentation/providers/auth_provider.dart';
import 'package:jobdun/features/auth/presentation/widgets/onboarding_completion_sheet.dart';
import 'package:jobdun/features/profile/domain/entities/user_profile.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';

/// G4 regression suite: after Sign in with Apple/Google the completion sheet
/// must never require the user's name — role (+ skippable avatar) only.
class _FakeAuthController extends AuthController {
  _FakeAuthController(this._seed);
  final AuthState _seed;

  bool completeCalled = false;
  UserRole? completedRole;
  String? completedName;

  @override
  AuthState build() => _seed;

  @override
  Future<bool> completeOnboarding({
    required UserRole role,
    String? displayName,
  }) async {
    completeCalled = true;
    completedRole = role;
    completedName = displayName;
    state = state.copyWith(role: role, isRoleLoaded: true);
    return true;
  }
}

class _FakeProfileController extends ProfileController {
  _FakeProfileController(this._seed);
  final ProfileState _seed;

  @override
  ProfileState build() => _seed;

  @override
  Future<void> loadProfile() async {
    // no-op in tests — the sheet refreshes the profile after finishing.
  }
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
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  // Ahem-font fallback renders wider than production; drain the harmless
  // overflow artifact like the other auth widget tests do.
  void drainKnownOverflow(WidgetTester tester) {
    final exc = tester.takeException();
    if (exc == null) return;
    if (exc.toString().contains('overflow')) return;
    throw exc;
  }

  Future<_FakeAuthController> pumpSheet(
    WidgetTester tester, {
    required AuthState auth,
    required ProfileState profile,
  }) async {
    final fakeAuth = _FakeAuthController(auth);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => fakeAuth),
          profileControllerProvider.overrideWith(
            () => _FakeProfileController(profile),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            theme: AppTheme.dark(),
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => OnboardingCompletionSheet.show(context),
                    child: const Text('OPEN'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);
    return fakeAuth;
  }

  testWidgets(
    'apple user with no captured name: role then avatar, finishes with null name',
    (tester) async {
      final fakeAuth = await pumpSheet(
        tester,
        auth: const AuthState(
          isAuthenticated: true,
          isRoleLoaded: true,
          ssoNameProvider: true,
        ),
        profile: const ProfileState(profile: UserProfile(id: 'u1')),
      );

      // Role step first.
      expect(find.text("I'M LOOKING FOR WORK"), findsOneWidget);

      await tester.tap(find.text("I'M LOOKING FOR WORK"));
      await tester.pumpAndSettle();
      drainKnownOverflow(tester);

      // Straight to the avatar step — a 2-step plan, no name screen (G4).
      expect(find.text('Add a profile photo?'), findsOneWidget);
      expect(find.text('STEP 2 OF 2'), findsOneWidget);

      await tester.tap(find.text('SKIP'));
      await tester.pumpAndSettle();
      drainKnownOverflow(tester);

      expect(fakeAuth.completeCalled, isTrue);
      expect(fakeAuth.completedRole, UserRole.trade);
      expect(fakeAuth.completedName, isNull);
    },
  );

  testWidgets('apple user with captured metadata name persists it silently', (
    tester,
  ) async {
    final fakeAuth = await pumpSheet(
      tester,
      auth: const AuthState(
        isAuthenticated: true,
        isRoleLoaded: true,
        ssoNameProvider: true,
        metadataDisplayName: 'Kel Tradie',
      ),
      profile: const ProfileState(profile: UserProfile(id: 'u1')),
    );

    await tester.tap(find.text("I'M HIRING"));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(find.text('Add a profile photo?'), findsOneWidget);

    await tester.tap(find.text('SKIP'));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(fakeAuth.completedRole, UserRole.builder);
    expect(fakeAuth.completedName, 'Kel Tradie');
  });

  testWidgets('phone user with no name still gets the name step', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      auth: const AuthState(isAuthenticated: true, isRoleLoaded: true),
      profile: const ProfileState(profile: UserProfile(id: 'u1')),
    );

    await tester.tap(find.text("I'M LOOKING FOR WORK"));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    // Name step present for providers that never supply a name.
    expect(find.text('STEP 2 OF 3'), findsOneWidget);
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.text('Add a profile photo?'), findsNothing);
  });
}
