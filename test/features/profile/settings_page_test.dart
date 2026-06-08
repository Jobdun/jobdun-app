import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/profile/presentation/pages/settings_page.dart';

// S6: settings live on their own /settings route now, not inline on /profile.
// The page must still surface every settings group + the sign-out action that
// used to sit at the bottom of the profile body.
void main() {
  Widget wrap() => ProviderScope(
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
