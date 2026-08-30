import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_colors.dart';
import 'package:jobdun/features/auth/presentation/providers/auth_provider.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';
import 'package:jobdun/features/profile/domain/entities/user_profile.dart';
import 'package:jobdun/features/profile/presentation/pages/profile_page.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';

/// Whole-screen golden for the TRADE half of the Figma **Profile** frame
/// (`JobDun-Screens` node 131:8006) — the counterpart to
/// figma_builder_profile_test.dart.
///
/// The trade body was the one section the Figma refresh skipped (the builder
/// body, the shared rows and the header were all migrated), so this golden
/// exists to pin the migrated result: the three-up figure row, sentence-case
/// section headings, and the details card in the refreshed vocabulary.
class _FakeProfileController extends ProfileController {
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
      yearsExperience: 8,
      jobsCompleted: 12,
      averageRating: 4.6,
      ratingCount: 9,
      baseSuburb: 'Balcatta',
      baseState: 'WA',
      serviceRadiusKm: 30,
      crewSize: 3,
      hourlyRateMin: 65,
      hourlyRateMax: 95,
      about:
          'Second-gen chippie. Decks, pergolas and full fit-outs across '
          'the northern suburbs.',
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

void main() {
  testWidgets('Trade profile (light)', (tester) async {
    const surface = Size(393, 852);
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileControllerProvider.overrideWith(_FakeProfileController.new),
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
                scaffoldBackgroundColor: JColors.light.background,
                extensions: const [JColors.light],
              ),
              home: const ProfilePage(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await expectLater(
      find.byType(ProfilePage),
      matchesGoldenFile('goldens/figma_trade_profile.png'),
    );
  });
}
