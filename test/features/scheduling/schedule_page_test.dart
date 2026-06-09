import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/scheduling/domain/entities/booking.dart';
import 'package:jobdun/features/scheduling/presentation/pages/schedule_page.dart';
import 'package:jobdun/features/scheduling/presentation/providers/scheduling_provider.dart';

Widget _wrap(List<Booking> data, {String uid = 'b1'}) => ProviderScope(
  overrides: [
    myBookingsProvider.overrideWith((ref) async => data),
    currentUserIdSyncProvider.overrideWithValue(uid),
  ],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) =>
        MaterialApp(theme: AppTheme.dark(), home: const SchedulePage()),
  ),
);

void main() {
  testWidgets('an empty day shows the no-work message', (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();

    expect(find.text('No work scheduled for this day.'), findsOneWidget);
  });

  testWidgets('a booking on the selected day shows its tile', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final booking = Booking(
      id: 'bk1',
      jobId: 'j1',
      builderId: 'b1',
      tradeId: 't1',
      scheduledDate: today,
      status: BookingStatus.scheduled,
      createdAt: DateTime(2026),
      jobTitle: 'Deck build',
      tradeFullName: 'Jo Tradie',
    );

    await tester.pumpWidget(_wrap([booking]));
    await tester.pumpAndSettle();

    expect(find.text('Deck build'), findsOneWidget);
    expect(find.text('Jo Tradie'), findsOneWidget);
    expect(find.text('MARK DONE'), findsOneWidget);
  });
}
