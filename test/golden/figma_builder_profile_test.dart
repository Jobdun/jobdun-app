import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_colors.dart';
import 'package:jobdun/features/auth/presentation/providers/auth_provider.dart';
import 'package:jobdun/features/auth/presentation/providers/auth_state.dart';
import 'package:jobdun/features/profile/domain/entities/builder_profile.dart';
import 'package:jobdun/features/profile/domain/entities/user_profile.dart';
import 'package:jobdun/features/profile/presentation/pages/profile_page.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';

/// Whole-screen golden for the Figma **Profile** frame (`JobDun-Screens` node
/// 131:8006) — the BUILDER profile: identity card, completion nudge, the
/// Jobs Posted / Hires / In-business figure row, About the company, Company
/// Details and Reviews.
class _FakeProfileController extends ProfileController {
  @override
  ProfileState build() => const ProfileState(
    profile: UserProfile(
      id: 'b1',
      displayName: 'QA Test Builder',
      email: 'qa.builder.test@jobdun.com.au',
    ),
    builderProfile: BuilderProfile(id: 'b1', companyName: ''),
  );
}

class _FakeAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    isRoleLoaded: true,
    role: UserRole.builder,
    email: 'qa.builder.test@jobdun.com.au',
  );
}

void main() {
  testWidgets('Builder profile (light)', (tester) async {
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
      matchesGoldenFile('goldens/figma_builder_profile.png'),
    );
  });
}
