part of 'message_thread_page.dart';

// Presentational leaves for the thread page (bubble, day separator, empty
// state) + grouping helpers — split into a `part` so message_thread_page.dart
// stays under the file-size budget. Single-use, co-located with their caller.

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.initials,
    required this.showAvatar,
    required this.groupedWithPrev,
    required this.lastInGroup,
  });

  final Message message;
  final bool isMine;
  final String initials;
  // Incoming avatar renders only on the last bubble of a run; a spacer keeps
  // earlier bubbles in the group aligned with it.
  final bool showAvatar;
  // Continuation of the same sender within the group window → tighter corner
  // on the top of the spine side; bigger gap + timestamp only when the group
  // ends (lastInGroup).
  final bool groupedWithPrev;
  final bool lastInGroup;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final round = Radius.circular(16.r);
    final tight = Radius.circular(5.r);

    return Padding(
      padding: EdgeInsets.only(bottom: lastInGroup ? 10.h : 2.h),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine)
            showAvatar
                ? Padding(
                    padding: EdgeInsets.only(right: AppSpacing.sm.w),
                    child: Container(
                      width: 28.r,
                      height: 28.r,
                      decoration: BoxDecoration(
                        color: c.surfaceRaised,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: tt.labelSmall!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.action,
                        ),
                      ),
                    ),
                  )
                : Gap(28.r + AppSpacing.sm.w),
          Flexible(
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: isMine ? c.action : c.card,
                    borderRadius: BorderRadius.only(
                      topLeft: isMine || !groupedWithPrev ? round : tight,
                      topRight: !isMine || !groupedWithPrev ? round : tight,
                      bottomLeft: isMine || lastInGroup ? round : tight,
                      bottomRight: !isMine || lastInGroup ? round : tight,
                    ),
                    border: isMine ? null : Border.all(color: c.border),
                  ),
                  child: Text(
                    message.body,
                    style: tt.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w400,
                      color: isMine
                          ? Colors
                                .white // intentional
                          : c.text1,
                      height: 1.45,
                    ),
                  ),
                ),
                if (lastInGroup) ...[
                  Gap(4.h),
                  Text(
                    _fmtTime(message.createdAt),
                    style: tt.labelSmall!.copyWith(color: c.text3),
                  ),
                ],
              ],
            ),
          ),
          if (isMine) Gap(AppSpacing.sm.w),
        ],
      ),
    );
  }

  static String _fmtTime(DateTime t) {
    final local = t.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m ${local.hour < 12 ? 'AM' : 'PM'}';
  }
}

// Centered day pill ("TODAY" / "YESTERDAY" / "MON 12 JUN") between message
// groups that cross a calendar day.
class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(100.r),
            border: Border.all(color: c.border),
          ),
          child: Text(
            _dayLabel(date),
            style: tt.labelSmall!.copyWith(
              color: c.text3,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

bool _sameDayLocal(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

String _dayLabel(DateTime d) {
  const months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  final local = d.toLocal();
  final now = DateTime.now();
  final that = DateTime(local.year, local.month, local.day);
  final diff = DateTime(now.year, now.month, now.day).difference(that).inDays;
  if (diff == 0) return 'TODAY';
  if (diff == 1) return 'YESTERDAY';
  return '${days[that.weekday - 1]} ${that.day} ${months[that.month - 1]}';
}

class _ThreadEmpty extends StatelessWidget {
  const _ThreadEmpty({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.chat, size: AppIconSize.hero.r, color: c.text3),
            Gap(AppSpacing.md.h),
            Text(
              'NO MESSAGES YET.',
              style: tt.headlineSmall!.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text1,
              ),
            ),
            Gap(AppSpacing.sm.h),
            Text(
              'Say hello to $name to get the conversation started.',
              style: tt.bodyLarge!.copyWith(color: c.text3, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
