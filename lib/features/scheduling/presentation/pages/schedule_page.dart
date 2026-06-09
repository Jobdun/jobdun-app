import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../timesheets/presentation/pages/timesheet_args.dart';
import '../../domain/entities/booking.dart';
import '../providers/scheduling_provider.dart';
import 'schedule_logic.dart';

/// Shared schedule (#15). Both builders and trades see the days they have work
/// booked, with a per-day list. Builders create bookings from the hired
/// applicant screen; either party can mark a day done here.
class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = DateTime(now.year, now.month, now.day);
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final async = ref.watch(myBookingsProvider);
    final bookings = async.asData?.value ?? const <Booking>[];
    final meId = ref.watch(currentUserIdSyncProvider);
    final dayList = bookingsOn(bookings, _selectedDay);
    final now = DateTime.now();

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
                      title: 'Schedule',
                      size: PageHeaderSize.sub,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, AppSpacing.xl.h),
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.sm.w),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card.r),
                      border: Border.all(color: c.border),
                    ),
                    child: TableCalendar<Booking>(
                      firstDay: DateTime(now.year - 1, now.month, now.day),
                      lastDay: DateTime(now.year + 1, now.month, now.day),
                      focusedDay: _focusedDay,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      availableGestures: AvailableGestures.horizontalSwipe,
                      selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                      eventLoader: (day) => bookingsOn(bookings, day),
                      onDaySelected: (sel, foc) => setState(() {
                        _selectedDay = sel;
                        _focusedDay = foc;
                      }),
                      onPageChanged: (foc) => _focusedDay = foc,
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
                        markerDecoration: BoxDecoration(
                          color: c.action,
                          shape: BoxShape.circle,
                        ),
                        markersMaxCount: 1,
                        selectedDecoration: BoxDecoration(
                          color: c.action,
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
                        defaultTextStyle: tt.bodyMedium!.copyWith(
                          color: c.text1,
                        ),
                        weekendTextStyle: tt.bodyMedium!.copyWith(
                          color: c.text1,
                        ),
                        outsideTextStyle: tt.bodyMedium!.copyWith(
                          color: c.text3,
                        ),
                      ),
                    ),
                  ),
                  Gap(AppSpacing.lg.h),
                  if (async.hasError)
                    Text(
                      "Couldn't load your schedule.",
                      style: tt.bodyMedium!.copyWith(color: c.text2),
                    )
                  else if (dayList.isEmpty)
                    Text(
                      'No work scheduled for this day.',
                      style: tt.bodyMedium!.copyWith(color: c.text2),
                    )
                  else
                    ...dayList.map((b) => _BookingTile(booking: b, meId: meId)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingTile extends ConsumerWidget {
  const _BookingTile({required this.booking, required this.meId});

  final Booking booking;
  final String? meId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    // Show the other party: a builder sees the tradie; a tradie sees the company.
    final other = booking.builderId == meId
        ? (booking.tradeFullName ?? 'Tradesperson')
        : (booking.builderCompanyName ?? 'Builder');

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            booking.jobTitle ?? 'A job',
            style: tt.titleMedium!.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w700,
            ),
          ),
          Gap(2.h),
          Text(other, style: tt.bodyMedium!.copyWith(color: c.text2)),
          if ((booking.note ?? '').trim().isNotEmpty) ...[
            Gap(AppSpacing.sm.h),
            Text(
              booking.note!.trim(),
              style: tt.bodyMedium!.copyWith(color: c.text2),
            ),
          ],
          Gap(AppSpacing.sm.h),
          Row(
            children: [
              Text(
                booking.status.label.toUpperCase(),
                style: tt.labelSmall!.copyWith(
                  color: booking.isActive ? c.action : c.text3,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push(
                  '/timesheets',
                  extra: TimesheetArgs(
                    jobId: booking.jobId,
                    builderId: booking.builderId,
                    tradeId: booking.tradeId,
                    jobTitle: booking.jobTitle,
                  ),
                ),
                child: Text(
                  'TIMESHEET',
                  style: tt.labelMedium!.copyWith(
                    color: c.text2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (booking.isActive)
                TextButton(
                  onPressed: () => ref
                      .read(bookingActionsProvider)
                      .setStatus(booking.id, BookingStatus.completed),
                  child: Text(
                    'MARK DONE',
                    style: tt.labelMedium!.copyWith(
                      color: c.action,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
