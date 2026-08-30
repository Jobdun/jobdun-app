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

  // Sentence case since 2026-08-29 — rebuilt on the Figma Setting frame
  // (node 134:8995), which sets every group title and button in sentence case.
  testWidgets('renders the settings groups + both account actions', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Legal'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Delete my account'), findsOneWidget);
  });

  // The delete button sits 16dp under Log out per the mock, so the confirm
  // sheet is the only thing standing between a mis-tap and an irreversible
  // deletion. If this ever fails, do not "fix" it by loosening the assertion.
  testWidgets('delete opens a confirm sheet rather than deleting', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();

    // A confirmation is surfaced; nothing is deleted on the tap itself.
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.textContaining('There is no undo.'), findsOneWidget);
  });
}
