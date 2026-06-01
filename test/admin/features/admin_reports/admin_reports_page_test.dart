import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/admin/features/admin_auth/presentation/providers/admin_session_provider.dart';
import 'package:jobdun/admin/features/admin_reports/presentation/pages/admin_reports_page.dart';
import 'package:jobdun/app/theme/app_theme.dart';

import '../../support/admin_test_support.dart';

Widget _wrap(Widget page) => ProviderScope(
  overrides: [
    adminSessionProvider.overrideWith(
      () => FakeAdminSessionNotifier(kTestAdminSession),
    ),
  ],
  child: ScreenUtilInit(
    designSize: const Size(1440, 900),
    builder: (_, _) => MaterialApp(theme: AppTheme.dark(), home: page),
  ),
);

void main() {
  testWidgets('renders the M4 reports placeholder with a disabled action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const AdminReportsPage()));
    await tester.pump();

    expect(find.text('MODERATION REPORTS'), findsOneWidget);
    expect(find.text('REPORT QUEUE'), findsOneWidget);
    expect(find.text('REVIEW'), findsOneWidget);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull); // placeholder action is disabled
    expect(tester.takeException(), isNull); // no overflow / layout error
  });
}
