import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/admin/features/admin_auth/presentation/providers/admin_session_provider.dart';
import 'package:jobdun/admin/features/admin_jobs/domain/entities/admin_job_row.dart';
import 'package:jobdun/admin/features/admin_jobs/presentation/pages/admin_job_detail_page.dart';
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
  setUp(() {
    // Wide enough that the scaffold renders the expanded sidebar + detail body.
  });

  testWidgets('renders real row facts and disabled moderation actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final row = AdminJobRow(
      id: 'j1',
      title: 'Site cleanup crew',
      status: 'open',
      builderDisplayName: 'Acme Builders',
      applicationCount: 4,
      createdAt: DateTime(2026, 5, 20),
    );

    await tester.pumpWidget(_wrap(AdminJobDetailPage(jobId: 'j1', row: row)));
    await tester.pump();

    expect(find.text('Site cleanup crew'), findsOneWidget);
    expect(find.text('Acme Builders'), findsOneWidget);
    expect(find.text('HIDE'), findsOneWidget);
    expect(find.text('REMOVE'), findsOneWidget);

    // Both moderation actions are placeholders → disabled.
    final buttons = tester.widgetList<FilledButton>(find.byType(FilledButton));
    expect(buttons, isNotEmpty);
    expect(buttons.every((b) => b.onPressed == null), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a null row (deep link) shows the empty state, not a crash', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const AdminJobDetailPage(jobId: 'j1')));
    await tester.pump();

    expect(find.text('OPEN A JOB FROM THE LIST'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
