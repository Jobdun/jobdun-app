import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/jobs/presentation/pages/job_apply_sheet.dart';
import 'package:jobdun/features/jobs/presentation/pages/job_detail_args.dart';

JobDetailArgs _args() => const JobDetailArgs(
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
  testWidgets('routes the prefilled rate + typed cover note to onSubmit', (
    tester,
  ) async {
    double? gotRate;
    String? gotNote;

    await tester.pumpWidget(
      _wrap(
        JobApplySheet(
          args: _args(),
          onSubmit: (rate, note) async {
            gotRate = rate;
            gotNote = note;
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
    await tester.tap(find.text('SUBMIT APPLICATION'));
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
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SUBMIT APPLICATION'));
    await tester.pumpAndSettle();

    expect(submitted, isTrue);
    expect(gotNote, isNull);
  });
}
