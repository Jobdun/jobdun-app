import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jobdun/admin/features/admin_auth/presentation/providers/admin_session_provider.dart';
import 'package:jobdun/admin/features/admin_dashboard/domain/entities/admin_dashboard_stats.dart';
import 'package:jobdun/admin/features/admin_dashboard/presentation/providers/admin_dashboard_stats_provider.dart';
import 'package:jobdun/admin/features/admin_shell/presentation/pages/admin_dashboard_page.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/errors/failures.dart';

import '../../support/admin_test_support.dart';

Widget _wrapDashboard() {
  const stats = AdminDashboardStats(
    totalUsers: 12,
    pendingVerifications: 3,
    openJobs: 7,
    rejectedLast7Days: 1,
  );

  return ProviderScope(
    overrides: [
      adminSessionProvider.overrideWith(
        () => FakeAdminSessionNotifier(kTestAdminSession),
      ),
      adminDashboardStatsRepositoryProvider.overrideWithValue(
        FakeDashboardStatsRepository(
          Right<Failure, AdminDashboardStats>(stats),
        ),
      ),
    ],
    child: ScreenUtilInit(
      designSize: const Size(1440, 900),
      builder: (_, _) =>
          MaterialApp(theme: AppTheme.dark(), home: const AdminDashboardPage()),
    ),
  );
}

void main() {
  testWidgets('dashboard shows the domain deployment snapshot', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrapDashboard());
    await tester.pump();

    expect(find.text('DOMAIN DEPLOYMENT'), findsOneWidget);
    expect(find.text('jobdun.com.au'), findsOneWidget);
    expect(find.text('CURRENT LIVE'), findsOneWidget);
    expect(find.text('GoDaddy DPS placeholder detected'), findsOneWidget);
    expect(find.text('REPO TARGET'), findsOneWidget);
    expect(
      find.text('Flutter web marketing bundle + Cloudflare Pages'),
      findsOneWidget,
    );
    expect(find.text('ADMIN TARGET'), findsOneWidget);
    expect(find.text('Cloudflare Pages project: jobdun-admin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
