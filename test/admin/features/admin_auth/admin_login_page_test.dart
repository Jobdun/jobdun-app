import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/admin/features/admin_auth/presentation/pages/admin_login_page.dart';
import 'package:jobdun/admin/features/admin_auth/presentation/providers/admin_session_provider.dart';
import 'package:jobdun/app/theme/app_theme.dart';

import '../../support/admin_test_support.dart';

// Signed out → the login screen is shown (session resolves to null). The page
// builds its own Scaffold but reads colours via context.c, so it needs the
// JColors theme attached through MaterialApp.theme.
Widget _login() => ProviderScope(
  overrides: [
    adminSessionProvider.overrideWith(() => FakeAdminSessionNotifier(null)),
  ],
  child: ScreenUtilInit(
    designSize: const Size(1440, 900),
    builder: (_, _) =>
        MaterialApp(theme: AppTheme.dark(), home: const AdminLoginPage()),
  ),
);

void main() {
  testWidgets(
    'wide viewport shows the split: brand panel + sign-in, no overflow',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_login());
      await tester.pump();

      expect(find.text('RUN THE PLATFORM.'), findsOneWidget); // brand panel
      expect(find.text('SIGN IN'), findsOneWidget); // form header
      expect(find.text('LOG IN'), findsOneWidget); // CTA
      expect(find.text('JOBDUN'), findsOneWidget); // lockup
      expect(tester.takeException(), isNull); // catches RenderFlex overflow
    },
  );

  testWidgets('narrow viewport stacks the form and drops the brand headline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(560, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_login());
    await tester.pump();

    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('LOG IN'), findsOneWidget);
    expect(find.text('RUN THE PLATFORM.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
