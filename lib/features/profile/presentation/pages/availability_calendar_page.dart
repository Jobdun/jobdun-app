import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../providers/profile_provider.dart';
import 'availability_calendar_logic.dart';

/// Trade availability calendar (#13). The trade taps upcoming dates to block
/// them off (booked / on leave); each toggle writes through to
/// `trade_profiles.unavailable_dates`. Builders read those dates on the trade's
/// profile. Reached from Settings → Availability calendar (trade accounts).
class AvailabilityCalendarPage extends ConsumerStatefulWidget {
  const AvailabilityCalendarPage({super.key});

  @override
  ConsumerState<AvailabilityCalendarPage> createState() =>
      _AvailabilityCalendarPageState();
}

class _AvailabilityCalendarPageState
    extends ConsumerState<AvailabilityCalendarPage> {
  late final DateTime _today;
  late DateTime _focusedDay;
  late List<DateTime> _dates;

  @override
  void initState() {
    super.initState();
    _today = dateOnly(DateTime.now());
    _focusedDay = _today;
    _dates = List<DateTime>.from(
      ref.read(profileControllerProvider).tradeProfile?.unavailableDates ??
          const <DateTime>[],
    );
  }

  Future<void> _toggle(DateTime day) async {
    final picked = dateOnly(day);
    if (picked.isBefore(_today)) return;

    final prev = _dates;
    final next = toggleUnavailableDay(_dates, picked);
    setState(() {
      _dates = next;
      _focusedDay = picked;
    });

    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .setTradeUnavailableDates(next);
    if (!mounted) return;
    if (!ok) {
      setState(() => _dates = prev);
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't update availability. Try again."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final isTrade = ref.watch(
      profileControllerProvider.select((s) => s.tradeProfile != null),
    );

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: c.card,
              padding: EdgeInsets.fromLTRB(4.w, AppSpacing.sm.h, 20.w, 12.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(
                      AppIcons.back,
                      size: AppIconSize.md.r,
                      color: c.text1,
                    ),
                  ),
                  const Expanded(
                    child: PageHeader(
                      title: 'Availability',
                      size: PageHeaderSize.sub,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            Expanded(
              child: isTrade
                  ? _Body(
                      today: _today,
                      focusedDay: _focusedDay,
                      dates: _dates,
                      onToggle: _toggle,
                      onPageChanged: (d) => _focusedDay = d,
                    )
                  : Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg.w),
                        child: Text(
                          'The availability calendar is for trade accounts.',
                          textAlign: TextAlign.center,
                          style: tt.bodyLarge!.copyWith(color: c.text2),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The intro line, the month calendar, and the blocked-days summary.
class _Body extends StatelessWidget {
  const _Body({
    required this.today,
    required this.focusedDay,
    required this.dates,
    required this.onToggle,
    required this.onPageChanged,
  });

  final DateTime today;
  final DateTime focusedDay;
  final List<DateTime> dates;
  final ValueChanged<DateTime> onToggle;
  final ValueChanged<DateTime> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, AppSpacing.xl.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tap a day to block it off when you’re booked or away. Builders '
            'see these on your profile; your “open for work” toggle is separate.',
            style: tt.bodyMedium!.copyWith(color: c.text2),
          ),
          Gap(AppSpacing.lg.h),
          Container(
            padding: EdgeInsets.all(AppSpacing.sm.w),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadius.card.r),
              border: Border.all(color: c.border),
            ),
            child: TableCalendar<void>(
              firstDay: today,
              lastDay: DateTime(today.year + 1, today.month, today.day),
              focusedDay: focusedDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              availableGestures: AvailableGestures.horizontalSwipe,
              enabledDayPredicate: (day) => !day.isBefore(today),
              selectedDayPredicate: (day) => isDayUnavailable(dates, day),
              onDaySelected: (selected, _) => onToggle(selected),
              onPageChanged: onPageChanged,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                leftChevronIcon: Icon(
                  AppIcons.back,
                  size: AppIconSize.md.r,
                  color: c.text1,
                ),
                rightChevronIcon: Icon(
                  AppIcons.chevronRight,
                  size: AppIconSize.md.r,
                  color: c.text1,
                ),
                titleTextStyle: tt.titleMedium!.copyWith(
                  color: c.text1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: tt.labelSmall!.copyWith(color: c.text3),
                weekendStyle: tt.labelSmall!.copyWith(color: c.text3),
              ),
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: c.urgent,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: tt.bodyMedium!.copyWith(
                  color: c.onAction,
                  fontWeight: FontWeight.w700,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.action, width: 1.5),
                ),
                todayTextStyle: tt.bodyMedium!.copyWith(color: c.text1),
                defaultTextStyle: tt.bodyMedium!.copyWith(color: c.text1),
                weekendTextStyle: tt.bodyMedium!.copyWith(color: c.text1),
                disabledTextStyle: tt.bodyMedium!.copyWith(color: c.text3),
                outsideTextStyle: tt.bodyMedium!.copyWith(color: c.text3),
              ),
            ),
          ),
          Gap(AppSpacing.md.h),
          Row(
            children: [
              Container(
                width: 12.r,
                height: 12.r,
                decoration: BoxDecoration(
                  color: c.urgent,
                  shape: BoxShape.circle,
                ),
              ),
              Gap(8.w),
              Text(
                dates.isEmpty
                    ? 'No days blocked off'
                    : '${dates.length} day${dates.length == 1 ? '' : 's'} blocked off',
                style: tt.bodyMedium!.copyWith(color: c.text2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
