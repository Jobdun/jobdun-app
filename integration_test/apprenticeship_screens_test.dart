import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/services/places_service.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';
import 'package:jobdun/features/jobs/presentation/pages/job_create_page.dart';
import 'package:jobdun/features/jobs/presentation/pages/job_apply_sheet.dart';
import 'package:jobdun/features/jobs/presentation/pages/job_detail_args.dart';

/// Real Android rendering of production screens with labelled synthetic inputs.
/// Database/RLS behavior is exercised separately by application_hiring.sql.
/// This does not publish test vacancies to the production marketplace.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Widget harness(Widget child) => ProviderScope(
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: child,
      ),
    ),
  );

  testWidgets('apprenticeship posting and application screens on Android', (
    tester,
  ) async {
    await tester.pumpWidget(harness(const JobCreatePage()));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apprenticeship'));
    await tester.pumpAndSettle();
    final form = tester.state<FormBuilderState>(find.byType(FormBuilder));
    form.patchValue({
      'title': 'Carpentry apprenticeship',
      'description':
          'Learn framing and finishing with an experienced crew. Weekday hours. First-year applicants welcome.',
      'trade': 'Carpenter',
      'suburb': 'Sydney',
      'state': 'NSW',
      'postcode': '2000',
      // Production defines enable the structured location picker. Legacy
      // suburb fields alone do not fill that branch of the real form.
      if (form.fields.containsKey('place'))
        'place': const JPlaceResult(
          placeId: 'synthetic-sydney',
          formattedAddress: 'Sydney, NSW 2000, Australia',
          suburb: 'Sydney',
          state: 'NSW',
          postcode: '2000',
          latitude: -33.8688,
          longitude: 151.2093,
          mainText: 'Sydney',
          secondaryText: 'NSW 2000, Australia',
        ),
    });
    await tester.pumpAndSettle();
    await binding.takeScreenshot(
      '2026-09-15-emulator-apprenticeship-01-details',
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Hourly pay'), findsOneWidget);
    form.fields['rate']!.didChange('25.75');
    await tester.pumpAndSettle();
    expect(find.text('Hourly pay'), findsOneWidget);
    await binding.takeScreenshot('2026-09-15-emulator-apprenticeship-02-pay');

    double? submittedQuote = 999;
    String? submittedNote;
    await tester.pumpWidget(
      harness(
        Scaffold(
          body: SafeArea(
            child: JobApplySheet(
              args: const JobDetailArgs(
                title: 'Carpentry apprenticeship',
                description: 'Learn on residential sites.',
                rate: '\$25.75/hr',
                startDate: 'To discuss',
                distanceKm: 0,
                isUrgent: false,
                jobKind: JobKind.apprenticeship,
                openToApprentices: true,
                pricingUnit: PricingUnit.hourly,
              ),
              onSubmit: (quote, note) async {
                submittedQuote = quote;
                submittedNote = note;
                return null;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final applicationForm = tester.state<FormBuilderState>(
      find.byType(FormBuilder),
    );
    final noteField = applicationForm.fields.values.first;
    noteField.didChange('I have my White Card and can start next month.');
    await tester.pumpAndSettle();
    expect(find.text('YOUR QUOTE'), findsNothing);
    await binding.takeScreenshot(
      '2026-09-15-emulator-apprenticeship-03-application',
    );
    await tester.tap(find.text('SEND APPLICATION'));
    await tester.pumpAndSettle();
    expect(submittedQuote, isNull);
    expect(submittedNote, contains('White Card'));
  });
}
