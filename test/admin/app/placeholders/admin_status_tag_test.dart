import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/admin/app/placeholders/admin_status_tag.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/theme/app_icons.dart';

Widget _wrap(Widget child) => ScreenUtilInit(
  designSize: const Size(1440, 900),
  builder: (_, _) => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('renders the label and the "soon" lock by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const AdminStatusTag(label: 'FREE', tooltip: 'Tier — Phase 3')),
    );
    await tester.pump();

    expect(find.text('FREE'), findsOneWidget);
    expect(find.byIcon(AppIcons.lock), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('omits the lock when soon is false', (tester) async {
    await tester.pumpWidget(
      _wrap(const AdminStatusTag(label: 'ACTIVE', soon: false)),
    );
    await tester.pump();

    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.byIcon(AppIcons.lock), findsNothing);
  });

  testWidgets('wraps in a Tooltip only when one is supplied', (tester) async {
    await tester.pumpWidget(
      _wrap(const AdminStatusTag(label: 'X', tooltip: 'why')),
    );
    await tester.pump();
    expect(find.byType(Tooltip), findsOneWidget);
  });
}
