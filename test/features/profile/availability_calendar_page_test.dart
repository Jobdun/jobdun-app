import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';
import 'package:jobdun/features/profile/presentation/pages/availability_calendar_page.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';
import 'package:table_calendar/table_calendar.dart';

/// Returns a fixed [ProfileState] without touching Supabase / currentUserId.
class _FakeProfileController extends ProfileController {
  _FakeProfileController(this._initial);
  final ProfileState _initial;
  @override
  ProfileState build() => _initial;
}

Widget _wrap(ProfileState state) => ProviderScope(
  overrides: [
    profileControllerProvider.overrideWith(() => _FakeProfileController(state)),
  ],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(
      theme: AppTheme.dark(),
      home: const AvailabilityCalendarPage(),
    ),
  ),
);

void main() {
  testWidgets('a trade sees the calendar + a blocked-days summary', (
    tester,
  ) async {
    const tp = TradeProfile(
      id: 't1',
      fullName: 'Jo Tradie',
      primaryTrade: 'carpenter',
      unavailableDates: [],
    );
    final withOneDay = TradeProfile(
      id: tp.id,
      fullName: tp.fullName,
      primaryTrade: tp.primaryTrade,
      unavailableDates: [DateTime(2026, 12, 25)],
    );

    await tester.pumpWidget(_wrap(ProfileState(tradeProfile: withOneDay)));
    await tester.pumpAndSettle();

    expect(find.byType(TableCalendar<void>), findsOneWidget);
    expect(find.text('1 day blocked off'), findsOneWidget);
  });

  testWidgets('a non-trade account sees the trade-only message', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ProfileState()));
    await tester.pump();

    expect(find.textContaining('trade accounts'), findsOneWidget);
    expect(find.byType(TableCalendar<void>), findsNothing);
  });
}
