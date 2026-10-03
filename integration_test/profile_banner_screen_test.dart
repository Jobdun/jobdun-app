import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/auth/presentation/providers/auth_provider.dart';
import 'package:jobdun/features/home/presentation/widgets/profile_completeness_banner.dart';
import 'package:jobdun/features/profile/domain/entities/builder_profile.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';
import 'package:jobdun/features/profile/domain/entities/user_profile.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';
import 'package:jobdun/features/verification/presentation/providers/verifications_provider.dart';

class _FixtureAuth extends AuthController {
  _FixtureAuth(this.role);
  final UserRole role;

  @override
  AuthState build() =>
      AuthState(isAuthenticated: true, isRoleLoaded: true, role: role);
}

class _FixtureProfile extends ProfileController {
  @override
  ProfileState build() => const ProfileState(
    profile: UserProfile(id: 'banner-fixture'),
    builderProfile: BuilderProfile(
      id: 'banner-fixture',
      companyName: 'Fixture Builder',
      abn: '12345678901',
    ),
    tradeProfile: TradeProfile(
      id: 'banner-fixture',
      fullName: 'Fixture Trade',
      primaryTrade: 'electrician',
      baseSuburb: 'Sydney',
      portfolioUrls: ['fixture-photo-not-loaded'],
    ),
  );
}

/// Android rendering evidence only: real banner, synthetic provider values.
/// Does not initialize Supabase, sign in, fetch records, or save profile data.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile banner copy matches the active role on Android', (
    tester,
  ) async {
    for (final role in [UserRole.trade, UserRole.builder]) {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(role),
          overrides: [
            authControllerProvider.overrideWith(() => _FixtureAuth(role)),
            profileControllerProvider.overrideWith(_FixtureProfile.new),
            currentUserIdProvider.overrideWith((ref) => Stream.value(null)),
            currentUserIdSyncProvider.overrideWithValue(null),
            myWizardLicenceVerifiedProvider.overrideWithValue(false),
          ],
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) => MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              home: Scaffold(
                appBar: AppBar(title: Text('${role.label} banner fixture')),
                body: const SafeArea(
                  child: SingleChildScrollView(
                    child: ProfileCompletenessBanner(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (role == UserRole.trade) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
      }

      final expected = role == UserRole.trade
          ? 'Add a few details to build trust and get more work'
          : 'Add a few details to build trust and get applicants';
      expect(find.text(expected), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          '${role == UserRole.trade ? 60 : 50} percent complete',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot(
        '2026-10-01-emulator-profile-banner-${role.name}',
      );
    }
  });
}
