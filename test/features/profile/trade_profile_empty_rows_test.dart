import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_colors.dart';
import 'package:jobdun/features/auth/presentation/providers/auth_provider.dart';
import 'package:jobdun/core/design/widgets/j_chip.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';
import 'package:jobdun/features/profile/domain/entities/user_profile.dart';
import 'package:jobdun/features/profile/presentation/pages/profile_page.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';

/// A tradie who has signed up but has no `trade_profiles` row yet.
///
/// Service area and Crew read non-null fields (`serviceRadiusKm`, `crewSize`)
/// off a nullable profile, so they used to fall back to the entity's
/// constructor defaults and state "50 km radius" and "Solo operator" as
/// though the tradie had answered. Nobody chose those — the row must read
/// Not Set, the same way the builder's in-business figure holds an em dash
/// rather than a real-looking 0 (P6, 2026-08-18 audit).
class _NoTradeProfileController extends ProfileController {
  @override
  ProfileState build() => const ProfileState(
    profile: UserProfile(
      id: 't1',
      displayName: 'QA Test Tradie',
      email: 'qa.tradie.test@jobdun.com.au',
    ),
  );
}

/// A tradie who has a `trade_profiles` row but has not picked a trade yet —
/// the case the Skills chip got wrong. `displayTrade` is empty here, and the
/// section used to key off the profile merely existing, so it rendered a bare
/// orange pill with no text in it.
class _BlankTradeController extends ProfileController {
  @override
  ProfileState build() => const ProfileState(
    profile: UserProfile(
      id: 't1',
      displayName: 'QA Test Tradie',
      email: 'qa.tradie.test@jobdun.com.au',
    ),
    tradeProfile: TradeProfile(
      id: 't1',
      fullName: 'QA Test Tradie',
      primaryTrade: '',
    ),
  );
}

/// A fully-populated tradie — used for the affordances that only exist once
/// the profile has an id to point at.
class _FullTradeController extends ProfileController {
  @override
  ProfileState build() => const ProfileState(
    profile: UserProfile(
      id: 't1',
      displayName: 'QA Test Tradie',
      email: 'qa.tradie.test@jobdun.com.au',
    ),
    tradeProfile: TradeProfile(
      id: 't1',
      fullName: 'QA Test Tradie',
      primaryTrade: 'carpenter',
    ),
  );
}

class _FakeAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    isRoleLoaded: true,
    role: UserRole.trade,
    email: 'qa.tradie.test@jobdun.com.au',
  );
}

Widget _harness(ProfileController Function() controller) {
  const surface = Size(393, 852);
  return ProviderScope(
    overrides: [
      profileControllerProvider.overrideWith(controller),
      authControllerProvider.overrideWith(_FakeAuthController.new),
    ],
    child: MediaQuery(
      data: const MediaQueryData(size: surface, devicePixelRatio: 1.0),
      child: ScreenUtilInit(
        designSize: surface,
        useInheritedMediaQuery: true,
        builder: (_, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            extensions: const [JColors.light],
          ),
          home: const ProfilePage(),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('trade profile with no trade row invents no answers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_harness(_NoTradeProfileController.new));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('50 km radius'), findsNothing);
    expect(find.text('Solo operator'), findsNothing);

    // Both rows are still present — they just hold the honest empty value.
    expect(find.text('Service area'), findsOneWidget);
    expect(find.text('Crew'), findsOneWidget);
    expect(find.text('Not Set'), findsWidgets);
  });

  testWidgets('a profile with no trade picked renders no empty Skills chip', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_harness(_BlankTradeController.new));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The heading only renders alongside a chip that has something in it.
    expect(find.text('Skills'), findsNothing);

    // The header's role chip is a JChip too, so assert the property that
    // actually broke: no chip anywhere on the page is a blank pill.
    final chips = tester.widgetList<JChip>(find.byType(JChip));
    expect(
      chips,
      isNotEmpty,
      reason: 'the header role chip should still be there',
    );
    expect(chips.where((chip) => chip.label.trim().isEmpty), isEmpty);
  });

  testWidgets('offers the tradie a preview of their public profile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_harness(_FullTradeController.new));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Parity with the builder profile's S12 link — a tradie could not see
    // what a builder sees until /trades/:id existed.
    expect(find.text('PREVIEW PUBLIC PROFILE'), findsOneWidget);
  });

  testWidgets('hides the preview link until there is a profile to preview', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_harness(_NoTradeProfileController.new));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('PREVIEW PUBLIC PROFILE'), findsNothing);
  });
}
