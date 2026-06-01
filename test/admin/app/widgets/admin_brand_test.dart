import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/admin/app/widgets/admin_brand.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/design/widgets/jobdun_logo.dart';

Widget _wrap(Widget child) => ScreenUtilInit(
  designSize: const Size(1440, 900),
  builder: (_, _) => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('lockup shows the badge, wordmark, and label', (tester) async {
    await tester.pumpWidget(_wrap(const AdminBrandLockup()));
    await tester.pump();

    expect(find.byType(JobdunLogo), findsOneWidget);
    expect(find.text('JOBDUN'), findsOneWidget);
    expect(find.text('ADMIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('label is configurable', (tester) async {
    await tester.pumpWidget(_wrap(const AdminBrandLockup(label: 'CONSOLE')));
    await tester.pump();
    expect(find.text('CONSOLE'), findsOneWidget);
  });
}
