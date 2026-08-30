import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/app/theme/app_colors.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/applications/domain/entities/job_application.dart';
import 'package:jobdun/features/applications/presentation/pages/applicant_detail_page.dart';
import 'package:jobdun/features/applications/presentation/pages/job_applicants_args.dart';
import 'package:jobdun/features/applications/presentation/providers/applications_provider.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';
import 'package:jobdun/features/profile/domain/repositories/profile_repository.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';
import 'package:jobdun/features/quotes/presentation/providers/quote_requests_provider.dart';
import 'package:jobdun/features/verification/presentation/providers/verifications_provider.dart';

import '_harness.dart';

class _MockProfileRepo extends Mock implements ProfileRepository {}

class _FakeApplications extends ApplicationsController {
  @override
  ApplicationsState build() => const ApplicationsState();
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

void main() {
  testWidgets('applicant detail golden (light)', (tester) async {
    final repo = _MockProfileRepo();
    when(() => repo.getTradeProfile(any())).thenAnswer(
      (_) async => right(
        const TradeProfile(
          id: 't-1',
          fullName: 'Ken Garcia',
          primaryTrade: 'Electrician',
          crewSize: 2,
          serviceRadiusKm: 50,
          baseSuburb: 'Marrickville',
          baseState: 'NSW',
        ),
      ),
    );

    final app = JobApplication(
      id: 'a-1',
      jobId: 'j-1',
      tradeId: 't-1',
      builderId: 'me',
      status: ApplicationStatus.pending,
      createdAt: DateTime(2026, 8, 29, 9),
      updatedAt: DateTime(2026, 8, 29, 9),
      jobTitle: 'Switchboard upgrade + install',
      jobSuburb: 'Marrickville',
      jobState: 'NSW',
      tradeFullName: 'Ken Garcia',
      tradePrimaryTrade: 'Electrician',
      tradeIsVerified: true,
      jobBudgetAmount: 110,
      jobPricingUnit: 'hourly',
      jobPricingType: 'builder_set',
      quoteAmount: 1050,
      coverNote:
          'Hi, I run a 2 man crew, 12 years on commercial switchboards. We '
          'can do Saturday 6am–2pm as you need. Certificate III in '
          'Electrotechnology and \$10M public liability — happy to send the '
          'licence scans on request.',
    );

    await tester.binding.setSurfaceSize(kGoldenSurface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          applicationsControllerProvider.overrideWith(_FakeApplications.new),
          // The trust/quote reads would hit Supabase; a golden only needs
          // their settled empty shapes.
          verificationsForUserProvider.overrideWith((ref, userId) async => []),
          tradePublicCredentialsProvider.overrideWith(
            (ref, userId) async => [],
          ),
          quoteRequestForProvider.overrideWith((ref, key) async => null),
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
              home: ApplicantDetailPage(
                args: ApplicantDetailArgs(
                  application: app,
                  jobTitle: 'Switchboard upgrade + install',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(ApplicantDetailPage),
      matchesGoldenFile('goldens/applicant_detail.png'),
    );
  });
}
