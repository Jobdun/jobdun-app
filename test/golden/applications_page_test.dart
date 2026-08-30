import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_colors.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/applications/domain/entities/job_application.dart';
import 'package:jobdun/features/applications/presentation/pages/applications_page.dart';
import 'package:jobdun/features/applications/presentation/providers/applications_provider.dart';
import 'package:jobdun/features/auth/presentation/providers/auth_provider.dart';

import '_harness.dart';

// Fixed builder session — AuthController.build() would otherwise reach for
// Supabase, and the applicants layout only exists for the builder role.
class _FakeAuth extends AuthController {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    isRoleLoaded: true,
    role: UserRole.builder,
  );
}

class _FakeApplications extends ApplicationsController {
  _FakeApplications(this._rows);

  final List<JobApplication> _rows;

  @override
  ApplicationsState build() => ApplicationsState(incomingApplications: _rows);
}

ThemeData _goldenTheme() {
  const c = JColors.light;
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: c.background,
    colorScheme: ColorScheme.light(
      primary: c.action,
      onPrimary: c.onAction,
      secondary: c.surfaceRaised,
      onSecondary: c.text1,
      surface: c.surface,
      onSurface: c.text1,
      error: c.urgent,
    ),
    extensions: const [c],
  );
}

JobApplication _app({
  required String id,
  required String title,
  required String trade,
  required ApplicationStatus status,
  double? quote,
}) => JobApplication(
  id: id,
  jobId: 'j-$id',
  tradeId: 't-$id',
  builderId: 'me',
  status: status,
  createdAt: DateTime.now().subtract(const Duration(minutes: 47)),
  updatedAt: DateTime.now(),
  jobTitle: title,
  jobSuburb: 'Marrickville',
  jobState: 'NSW',
  tradeFullName: trade,
  tradePrimaryTrade: 'Electrician',
  tradeIsVerified: true,
  jobBudgetAmount: 68,
  jobPricingUnit: 'hourly',
  jobPricingType: 'builder_set',
  quoteAmount: quote,
);

void main() {
  testWidgets('applicants page golden (light)', (tester) async {
    final rows = [
      _app(
        id: '1',
        title: 'Second fix carpentry — 8 townhouses',
        trade: 'Ken Garcia',
        status: ApplicationStatus.pending,
        quote: 1050,
      ),
      _app(
        id: '2',
        title: 'Switchboard update + RCD install',
        trade: 'Sam Boyd',
        status: ApplicationStatus.shortlisted,
      ),
      _app(
        id: '3',
        title: 'Roof restoration — re-bed and re-point 180 sqm',
        trade: 'Ali Tran',
        status: ApplicationStatus.rejected,
      ),
    ];

    await tester.binding.setSurfaceSize(kGoldenSurface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuth.new),
          applicationsControllerProvider.overrideWith(
            () => _FakeApplications(rows),
          ),
          currentUserIdProvider.overrideWith((ref) => Stream.value('me')),
          currentUserIdSyncProvider.overrideWithValue('me'),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            size: kGoldenSurface,
            devicePixelRatio: 1.0,
          ),
          child: ScreenUtilInit(
            designSize: kGoldenSurface,
            useInheritedMediaQuery: true,
            builder: (_, _) => MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: _goldenTheme(),
              home: const ApplicationsPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // JStaggeredList fades each card in on a per-index delay — advance past
    // the whole cascade so the golden captures settled cards.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await expectLater(
      find.byType(ApplicationsPage),
      matchesGoldenFile('goldens/applications_page.png'),
    );
  });
}
