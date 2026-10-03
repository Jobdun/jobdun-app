import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jobdun/features/profile/domain/entities/site_ticket.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/applications/domain/entities/job_application.dart';
import 'package:jobdun/features/applications/presentation/pages/applicant_detail_page.dart';
import 'package:jobdun/features/applications/presentation/pages/job_applicants_args.dart';
import 'package:jobdun/features/applications/presentation/providers/applications_provider.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';
import 'package:jobdun/features/profile/domain/repositories/profile_repository.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';
import 'package:jobdun/features/quotes/presentation/providers/quote_requests_provider.dart';
import 'package:jobdun/features/quotes/presentation/widgets/quote_request_builder_card.dart';
import 'package:jobdun/features/verification/presentation/providers/verifications_provider.dart';

import 'package:jobdun/features/profile/domain/entities/apprenticeship_stage.dart';
import 'package:jobdun/features/profile/presentation/providers/site_tickets_provider.dart';
import 'package:jobdun/features/profile/presentation/widgets/profile_tickets_section.dart';

const _designSize = Size(390, 844);

class _MockProfileRepo extends Mock implements ProfileRepository {}

class _FakeApplications extends ApplicationsController {
  @override
  ApplicationsState build() => const ApplicationsState();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('apprentice applicant review on Android', (tester) async {
    final repo = _MockProfileRepo();
    when(() => repo.getTradeProfile(any())).thenAnswer(
      (_) async => right(
        TradeProfile(
          id: 't-1',
          fullName: 'Alex Taylor',
          primaryTrade: 'Carpenter',
          crewSize: 2,
          isApprentice: true,
          apprenticeshipStage: ApprenticeshipStage.year2,
          siteTickets: ['white_card'],
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
      status: ApplicationStatus.shortlisted,
      createdAt: DateTime(2026, 8, 29, 9),
      updatedAt: DateTime(2026, 8, 29, 9),
      jobTitle: 'Carpentry apprenticeship',
      jobKind: 'apprenticeship',
      jobOpenToApprentices: true,
      tradeIsApprentice: true,
      tradeApprenticeshipStage: 'year_2',
      jobSuburb: 'Marrickville',
      jobState: 'NSW',
      tradeFullName: 'Alex Taylor',
      tradePrimaryTrade: 'Carpenter',
      tradeIsVerified: false,
      jobBudgetAmount: 25.75,
      jobPricingUnit: 'hourly',
      jobPricingType: 'builder_set',
      quoteAmount: null,
      coverNote:
          'I have my White Card and can start next month. I am looking to build my framing and finishing skills.',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          siteTicketsProvider.overrideWith(
            (ref) async => const [
              SiteTicket(
                slug: 'white_card',
                shortName: 'White Card',
                displayName: 'White Card (Construction Induction)',
                category: SiteTicketCategory.induction,
                sortOrder: 1,
              ),
            ],
          ),
          verifiedTicketSlugsProvider.overrideWith(
            (ref, id) async => <String>{},
          ),
          applicationsControllerProvider.overrideWith(_FakeApplications.new),
          // Synthetic fixtures isolate this rendering test from live records.
          verificationsForUserProvider.overrideWith((ref, userId) async => []),
          tradePublicCredentialsProvider.overrideWith(
            (ref, userId) async => [],
          ),
          quoteRequestForProvider.overrideWith((ref, key) async => null),
          currentUserIdProvider.overrideWith((ref) => Stream.value('me')),
          currentUserIdSyncProvider.overrideWithValue('me'),
        ],
        child: ScreenUtilInit(
          designSize: _designSize,
          builder: (_, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: ApplicantDetailPage(
              args: ApplicantDetailArgs(
                application: app,
                jobTitle: 'Carpentry apprenticeship',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    expect(find.text('Crew'), findsNothing);
    expect(find.text('Their quote · this job'), findsNothing);
    expect(find.byType(QuoteRequestBuilderCard), findsNothing);
    expect(find.text('Hire applicant'), findsOneWidget);
    expect(find.textContaining('2ND-YEAR'), findsOneWidget);
    expect(find.text('WHITE CARD'), findsOneWidget);
    expect(find.byType(ProfileTicketsSection), findsOneWidget);
    await binding.takeScreenshot(
      '2026-09-15-emulator-apprenticeship-04-applicant',
    );
  });
}
