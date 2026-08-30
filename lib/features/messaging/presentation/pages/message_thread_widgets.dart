part of 'message_thread_page.dart';

// Presentational leaves for the thread page (bubble, day separator, empty
// state) + grouping helpers — split into a `part` so message_thread_page.dart
// stays under the file-size budget. Single-use, co-located with their caller.

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.entry,
    required this.isMine,
    required this.initials,
    required this.showAvatar,
    required this.lastInGroup,
    required this.showSeenAvatar,
    this.imageUrl,
    this.onRetry,
    this.onLongPress,
  });

  final ThreadEntry entry;
  final bool isMine;
  final String initials;
  final String? imageUrl; // counterparty avatar for incoming bubbles
  // Incoming avatar renders only on the last bubble of a run; a spacer keeps
  // earlier bubbles in the group aligned with it.
  final bool showAvatar;
  // Last bubble of a same-sender run: closes the group with a 16dp gap and
  // the centred clock. Continuations stack tight (2dp) beneath it.
  final bool lastInGroup;
  // True only on the last of my messages the counterparty has read → render
  // their mini-avatar beneath it ("Seen").
  final bool showSeenAvatar;
  // Re-dispatch handler when this is a failed outbound message.
  final VoidCallback? onRetry;
  // Hold-to-open the actions sheet. Null for pending/deleted bubbles.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    // Figma `JobDun-Screens` → Messages (node 129:7423) draws every bubble on
    // one 16dp radius — no tightened corner on the spine side.
    final radius = BorderRadius.circular(AppRadius.cardLg.r);
    final isFailed = entry.status == MessageStatus.failed;
    final isDeleted = entry.isDeleted;
    // Dim my own bubble while the insert is still in flight.
    final mineColor = entry.status == MessageStatus.sending
        ? c.action.withValues(alpha: 0.6)
        : c.action;
    final bubbleColor = isDeleted
        ? c.surface
        : (isMine ? mineColor : c.surfaceRaised);
    // Figma fixes the bubble at 294 of a 393dp frame — a ceiling, not a fill,
    // so a two-word reply stays short and a long one wraps well before the
    // opposite margin.
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.75;
    // The clock only earns its line when the group actually closes; a failed
    // outbound message shows the retry affordance there instead.
    final showClock = !isDeleted && lastInGroup && !(isMine && isFailed);

    return Padding(
      padding: EdgeInsets.only(bottom: lastInGroup ? AppSpacing.md.h : 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: isMine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMine)
                showAvatar
                    ? Padding(
                        padding: EdgeInsets.only(right: 10.w),
                        child: AvatarBlock(
                          initials: initials,
                          imageUrl: imageUrl,
                          size: 32,
                          circle: true,
                        ),
                      )
                    : Gap(32.r + 10.w),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  child: Column(
                    crossAxisAlignment: isMine
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onLongPress: onLongPress,
                        child: entry.hasLocalImage && !isDeleted
                            ? _PendingChatImage(
                                localPath: entry.localImagePath!,
                                failed: entry.status == MessageStatus.failed,
                                onRetry: onRetry,
                              )
                            : entry.hasImage && !isDeleted
                            ? _ChatImage(
                                path: entry.attachmentPath!,
                                width: entry.attachmentW,
                                height: entry.attachmentH,
                              )
                            : Container(
                                padding: EdgeInsets.all(AppSpacing.md.r),
                                decoration: BoxDecoration(
                                  color: bubbleColor,
                                  borderRadius: radius,
                                  // Only the tombstone needs an edge — the
                                  // incoming bubble is defined by its own
                                  // `surfaceRaised` step off the ground.
                                  border: isDeleted
                                      ? Border.all(color: c.border)
                                      : null,
                                ),
                                child: isDeleted
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            AppIcons.trash,
                                            size: 14.r,
                                            color: c.text3,
                                          ),
                                          Gap(6.w),
                                          Text(
                                            'Message deleted',
                                            style: tt.bodyMedium!.copyWith(
                                              color: c.text3,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        entry.body,
                                        style: tt.bodyLarge!.copyWith(
                                          fontWeight: FontWeight.w400,
                                          color: isMine
                                              ? Colors
                                                    .white // intentional
                                              : c.text2,
                                          height: 1.4,
                                        ),
                                      ),
                              ),
                      ),
                      if (!isDeleted) ...[
                        // Failed (mine) → retry line. Image uploads carry
                        // their own retry overlay, so skip it for them.
                        if (isMine && isFailed && !entry.hasLocalImage)
                          _RetryLine(onRetry: onRetry),
                        if (entry.reactions.isNotEmpty) ...[
                          Gap(3.h),
                          _ReactionChips(reactions: entry.reactions),
                        ],
                        if (isMine && showSeenAvatar) ...[
                          Gap(3.h),
                          AvatarBlock(
                            initials: initials,
                            imageUrl: imageUrl,
                            size: 14,
                            circle: true,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Figma node 129:7515: the clock is a centred marker between groups,
          // not a caption tucked under one bubble.
          if (showClock) ...[
            Gap(AppSpacing.md.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _fmtTime(entry.createdAt),
                  style: tt.bodySmall!.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1.0,
                    color: c.text3,
                  ),
                ),
                if (entry.isEdited) ...[
                  Gap(4.w),
                  Text(
                    'edited',
                    style: tt.labelSmall!.copyWith(
                      color: c.text3,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (isMine) ...[Gap(4.w), _StatusTick(status: entry.status)],
              ],
            ),
          ],
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

// First-load shimmer: alternating placeholder bubbles masked by Skeletonizer,
// shown while message history is fetching (before any bubble exists).
class _ThreadSkeleton extends StatelessWidget {
  const _ThreadSkeleton();

  static const _rows = [
    (mine: false, w: 0.62),
    (mine: false, w: 0.40),
    (mine: true, w: 0.50),
    (mine: false, w: 0.70),
    (mine: true, w: 0.45),
    (mine: true, w: 0.34),
  ];

  @override
  Widget build(BuildContext context) {
    return JSkeletonList(
      enabled: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w,
          vertical: AppSpacing.md.h,
        ),
        child: Column(
          children: [
            for (var i = 0; i < _rows.length; i++) ...[
              if (i > 0) Gap(10.h),
              _SkeletonBubble(isMine: _rows[i].mine, widthFactor: _rows[i].w),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonBubble extends StatelessWidget {
  const _SkeletonBubble({required this.isMine, required this.widthFactor});

  final bool isMine;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return FractionallySizedBox(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 40.h,
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
        ),
      ),
    );
  }
}

// Incoming "typing…" bubble with three staggered bouncing dots.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
      ),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) Gap(4.w),
              Transform.scale(
                scale:
                    0.6 +
                    0.4 *
                        (1 - (2 * ((_ctrl.value + i * 0.22) % 1.0) - 1).abs()),
                child: Container(
                  width: 7.r,
                  height: 7.r,
                  decoration: BoxDecoration(
                    color: c.text3,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
