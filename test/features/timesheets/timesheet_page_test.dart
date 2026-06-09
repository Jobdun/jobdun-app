import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/timesheets/domain/entities/timesheet.dart';
import 'package:jobdun/features/timesheets/presentation/pages/timesheet_args.dart';
import 'package:jobdun/features/timesheets/presentation/pages/timesheet_page.dart';
import 'package:jobdun/features/timesheets/presentation/providers/timesheets_provider.dart';

const _args = TimesheetArgs(
  jobId: 'j1',
  builderId: 'b1',
  tradeId: 't1',
  jobTitle: 'Deck build',
);

Widget _wrap(List<Timesheet> data, {String me = 't1'}) => ProviderScope(
  overrides: [
    timesheetsForProvider.overrideWith((ref, key) async => data),
    currentUserIdSyncProvider.overrideWithValue(me),
  ],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(
      theme: AppTheme.dark(),
      home: const TimesheetPage(args: _args),
    ),
  ),
);

void main() {
  testWidgets('a trade with no entries can CHECK IN', (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();

    expect(find.text('CHECK IN'), findsOneWidget);
    expect(find.text('No time logged yet.'), findsOneWidget);
  });

  testWidgets('an open entry shows CHECK OUT', (tester) async {
    final open = Timesheet(
      id: 'ts1',
      jobId: 'j1',
      builderId: 'b1',
      tradeId: 't1',
      checkInAt: DateTime(2026, 6, 10, 8),
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(_wrap([open]));
    await tester.pumpAndSettle();

    expect(find.text('CHECK OUT'), findsOneWidget);
  });
}
