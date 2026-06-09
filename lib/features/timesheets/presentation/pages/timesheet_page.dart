import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../domain/entities/timesheet.dart';
import '../providers/timesheets_provider.dart';
import 'timesheet_args.dart';

/// Per-job timesheet (#16). The hired trade clocks on/off (capturing time + a
/// best-effort GPS fix); both parties see the entries. Reached from a booking
/// on the schedule.
class TimesheetPage extends ConsumerStatefulWidget {
  const TimesheetPage({super.key, required this.args});

  final TimesheetArgs args;

  @override
  ConsumerState<TimesheetPage> createState() => _TimesheetPageState();
}

class _TimesheetPageState extends ConsumerState<TimesheetPage> {
  bool _busy = false;

  Future<void> _clock(Timesheet? open) async {
    final a = widget.args;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(timesheetActionsProvider);
    final ok = open == null
        ? await actions.checkIn(
            jobId: a.jobId,
            builderId: a.builderId,
            tradeId: a.tradeId,
          )
        : await actions.checkOut(
            timesheetId: open.id,
            jobId: a.jobId,
            tradeId: a.tradeId,
          );
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (open == null ? 'Checked in.' : 'Checked out.')
              : "Couldn't update your timesheet. Try again.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final a = widget.args;
    final isTrade = ref.watch(currentUserIdSyncProvider) == a.tradeId;
    final async = ref.watch(
      timesheetsForProvider((jobId: a.jobId, tradeId: a.tradeId)),
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
                  Expanded(
                    child: PageHeader(
                      eyebrow: 'TIMESHEET',
                      title: (a.jobTitle ?? 'Job').trim(),
                      size: PageHeaderSize.sub,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            Expanded(
              child: async.when(
                loading: () => Center(
                  child: Text(
                    'Loading…',
                    style: tt.bodyMedium!.copyWith(color: c.text3),
                  ),
                ),
                error: (_, _) => Center(
                  child: Text(
                    "Couldn't load timesheets.",
                    style: tt.bodyMedium!.copyWith(color: c.text2),
                  ),
                ),
                data: (entries) {
                  Timesheet? open;
                  for (final t in entries) {
                    if (t.isOpen) {
                      open = t;
                      break;
                    }
                  }
                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      20.w,
                      20.h,
                      20.w,
                      AppSpacing.xl.h,
                    ),
                    children: [
                      if (isTrade)
                        SizedBox(
                          width: double.infinity,
                          child: JButton(
                            label: open == null ? 'CHECK IN' : 'CHECK OUT',
                            variant: open == null
                                ? JButtonVariant.primary
                                : JButtonVariant.danger,
                            isLoading: _busy,
                            onPressed: _busy ? null : () => _clock(open),
                          ),
                        ),
                      Gap(AppSpacing.lg.h),
                      if (entries.isEmpty)
                        Text(
                          'No time logged yet.',
                          style: tt.bodyMedium!.copyWith(color: c.text2),
                        )
                      else
                        ...entries.map((t) => _EntryTile(entry: t)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final Timesheet entry;

  String _fmt(DateTime d) => DateFormat('d MMM, h:mm a').format(d);

  String get _duration {
    final m = entry.durationMinutes;
    if (m == null) return 'In progress';
    final h = m ~/ 60;
    final mm = m % 60;
    return h > 0 ? '${h}h ${mm}m' : '${mm}m';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmt(entry.checkInAt),
                  style: tt.bodyLarge!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Gap(2.h),
                Text(
                  entry.checkOutAt == null
                      ? 'Still clocked on'
                      : 'until ${_fmt(entry.checkOutAt!)}',
                  style: tt.bodyMedium!.copyWith(color: c.text2),
                ),
              ],
            ),
          ),
          Text(
            _duration,
            style: tt.titleMedium!.copyWith(
              color: entry.isOpen ? c.action : c.text1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
