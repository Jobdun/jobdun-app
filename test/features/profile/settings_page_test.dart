import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/profile/presentation/pages/settings_page.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';

// Returns a fixed [ProfileState] so the page renders without Supabase. The
// availability tile is trade-gated, so a non-trade state keeps this test's
// scope (the always-present groups + sign out) unchanged.
class _FakeProfileController extends ProfileController {
  @override
  ProfileState build() => const ProfileState();
}

// S6: settings live on their own /settings route now, not inline on /profile.
// The page must still surface every settings group + the sign-out action that
// used to sit at the bottom of the profile body.
void main() {
  Widget wrap() => ProviderScope(
    overrides: [
      profileControllerProvider.overrideWith(_FakeProfileController.new),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) =>
          MaterialApp(theme: AppTheme.dark(), home: const SettingsPage()),
    ),
  );

  testWidgets('renders the settings groups + sign out', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('LEGAL'), findsOneWidget);
    expect(find.text('SIGN OUT'), findsOneWidget);
  });
}
