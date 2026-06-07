import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/design/widgets/j_offline_banner.dart';
import 'package:jobdun/core/theme/app_icons.dart';

void main() {
  testWidgets('JOfflineBanner shows the offline message + wifiOff icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: JOfflineBanner()),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('offline'), findsOneWidget);
    expect(find.byIcon(AppIcons.wifiOff), findsOneWidget);
  });
}
