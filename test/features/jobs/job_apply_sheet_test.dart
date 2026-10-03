import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/constants/app_strings.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/jobs/presentation/pages/job_apply_sheet.dart';
import 'package:jobdun/features/jobs/presentation/pages/job_detail_args.dart';

JobDetailArgs _args({bool openToApprentices = false}) => JobDetailArgs(
  openToApprentices: openToApprentices,
  id: 'job-1',
  title: 'Install 3-phase switchboard',
  description: 'Commercial site',
  rate: r'$85/hr',
  startDate: 'TBD',
  distanceKm: 0,
  isUrgent: false,
);

Widget _wrap(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: child),
  ),
);

void main() {
  for (final kind in JobKind.values) {
    testWidgets('$kind apprentice applications omit quote and can retry', (
      tester,
    ) async {
      double? gotRate = 99;
      String? gotNote;
      var calls = 0;
      final pending = Completer<String?>();
      await tester.pumpWidget(
        _wrap(
          JobApplySheet(
            isApprenticeApplicant: true,
            args: JobDetailArgs(
              id: 'job-1',
              title: 'Apprentice carpenter',
              description: 'Training',
              rate: r'$24.75/hr',
              startDate: 'TBD',
              distanceKm: 0,
              isUrgent: false,
              jobKind: kind,
              openToApprentices: kind == JobKind.tradeJob,
            ),
            onSubmit: (rate, note) async {
              calls++;
              gotRate = rate;
              gotNote = note;
              return calls == 1 ? pending.future : null;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('YOUR QUOTE'), findsNothing);
      expect(find.text(AppStrings.respondSheetTitle), findsNothing);
      expect(find.text('APPLY FOR THIS JOB'), findsOneWidget);
      expect(find.textContaining('resume'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '  Keen to learn  ');
      await tester.tap(find.text('SEND APPLICATION'));
      await tester.tap(find.text('SEND APPLICATION'));
      await tester.pump();
      expect(calls, 1);
      expect(gotRate, isNull);
      expect(gotNote, 'Keen to learn');
      pending.complete('Try again');
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('SEND APPLICATION'));
      await tester.pumpAndSettle();
      expect(calls, 2);
    });
  }

  testWidgets('qualified trades can quote on invited trade jobs', (
    tester,
  ) async {
    double? gotRate;
    String? gotNote;

    await tester.pumpWidget(
      _wrap(
        JobApplySheet(
          args: _args(openToApprentices: true),
          onSubmit: (rate, note) async {
            gotRate = rate;
            gotNote = note;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Rate field is prefilled from args.rate ('$85/hr' -> '85'); the second
    // TextField is the cover note.
    await tester.enterText(
      find.byType(TextField).last,
      'Available next week, fully licensed.',
    );
    await tester.tap(find.text(AppStrings.respondSubmit));
    await tester.pumpAndSettle();

    expect(gotRate, 85);
    expect(gotNote, 'Available next week, fully licensed.');
  });

  testWidgets('a blank cover note is passed as null', (tester) async {
    bool submitted = false;
    String? gotNote = 'sentinel';

    await tester.pumpWidget(
      _wrap(
        JobApplySheet(
          args: _args(),
          onSubmit: (rate, note) async {
            submitted = true;
            gotNote = note;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.respondSubmit));
    await tester.pumpAndSettle();

    expect(submitted, isTrue);
    expect(gotNote, isNull);
  });
}
