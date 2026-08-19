import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_button.dart';
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
    // P6, 2026-08-18 audit: keep any previously loaded value on a refresh
    // error; a failed FIRST load renders the page-level error below, never a
    // plausible empty calendar.
    final bookings = async.value ?? const <Booking>[];
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
              // P6, 2026-08-18 audit: a failed bookings load used to render an
              // empty calendar — error + RETRY instead.
              child: async.hasError && !async.hasValue
                  ? _ScheduleError(
                      onRetry: () => ref.invalidate(myBookingsProvider),
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        20.w,
                        20.h,
                        20.w,
                        AppSpacing.xl.h,
                      ),
                      children: [
                        Container(
                          padding: EdgeInsets.all(AppSpacing.sm.w),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(
                              AppRadius.card.r,
                            ),
                            border: Border.all(color: c.border),
                          ),
                          child: TableCalendar<Booking>(
                            firstDay: DateTime(
                              now.year - 1,
                              now.month,
                              now.day,
                            ),
                            lastDay: DateTime(now.year + 1, now.month, now.day),
                            focusedDay: _focusedDay,
                            startingDayOfWeek: StartingDayOfWeek.monday,
                            availableGestures:
                                AvailableGestures.horizontalSwipe,
                            selectedDayPredicate: (d) =>
                                isSameDay(d, _selectedDay),
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
                              weekdayStyle: tt.labelSmall!.copyWith(
                                color: c.text3,
                              ),
                              weekendStyle: tt.labelSmall!.copyWith(
                                color: c.text3,
                              ),
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
                              todayTextStyle: tt.bodyMedium!.copyWith(
                                color: c.text1,
                              ),
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
                          ...dayList.map(
                            (b) => _BookingTile(booking: b, meId: meId),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Full-page error + RETRY (P6, 2026-08-18 audit). Mirrors the jobs feed
// `_PageError` pattern (jobs_page_widgets.dart).
class _ScheduleError extends StatelessWidget {
  const _ScheduleError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.warning,
              size: AppIconSize.feature.r,
              color: c.urgent,
            ),
            Gap(AppSpacing.md.h),
            Text(
              "Couldn't load your schedule.",
              style: tt.bodyMedium!.copyWith(color: c.urgentTx),
              textAlign: TextAlign.center,
            ),
            Gap(AppSpacing.md.h),
            SizedBox(
              width: 160.w,
              child: JButton(
                label: 'RETRY',
                variant: JButtonVariant.secondary,
                onPressed: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingTile extends ConsumerStatefulWidget {
  const _BookingTile({required this.booking, required this.meId});

  final Booking booking;
  final String? meId;

  @override
  ConsumerState<_BookingTile> createState() => _BookingTileState();
}

class _BookingTileState extends ConsumerState<_BookingTile> {
  // P6, 2026-08-18 audit: MARK DONE used to fire-and-forget setStatus — no
  // in-flight state, no failure feedback, repeatable taps.
  bool _marking = false;

  Future<void> _markDone() async {
    if (_marking) return;
    setState(() => _marking = true);
    final messenger = ScaffoldMessenger.of(context);
    final c = context.c;
    final ok = await ref
        .read(bookingActionsProvider)
        .setStatus(widget.booking.id, BookingStatus.completed);
    if (!mounted) return;
    setState(() => _marking = false);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text("Couldn't update the booking. Try again."),
          backgroundColor: c.urgent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final meId = widget.meId;
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
                  onPressed: _marking ? null : _markDone,
                  child: Text(
                    _marking ? 'MARKING…' : 'MARK DONE',
                    style: tt.labelMedium!.copyWith(
                      color: _marking ? c.text3 : c.action,
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
