part of 'message_thread_page.dart';

// Send-status affordances for the thread (Phase A reliability core): the tick
// shown under your own messages, the failed/retry line, and the load-earlier
// pager. Split into a `part` so message_thread_page.dart + _widgets stay under
// the file-size budget. Single-use, co-located with their caller.

// Tiny status glyph under your own last-in-group message.
//   sending → clock · sent → single check · seen → orange double-check
// (the counterparty's mini-avatar is the primary "Seen" signal; the double
// check is a secondary cue.)
class _StatusTick extends StatelessWidget {
  const _StatusTick({required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (icon, color) = switch (status) {
      MessageStatus.sending => (Icons.schedule, c.text3),
      MessageStatus.sent => (Icons.check, c.text3),
      MessageStatus.seen => (Icons.done_all, c.action),
      MessageStatus.failed => (Icons.error_outline, c.urgent),
    };
    return Icon(icon, size: 13.r, color: color);
  }
}

// Failed-send row: a generous tap target that re-dispatches the message.
class _RetryLine extends StatelessWidget {
  const _RetryLine({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onRetry,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 13.r, color: c.urgent),
            Gap(4.w),
            Text(
              "Couldn't send · Tap to retry",
              style: tt.labelSmall!.copyWith(
                color: c.urgent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Top-of-thread pager shown while older history exists. Tapping loads the next
// older page (non-reversed list → no scroll-jump because the user initiates it).
class _LoadEarlierBar extends StatelessWidget {
  const _LoadEarlierBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(100.r),
              border: Border.all(color: c.border),
            ),
            child: Text(
              'Load earlier messages',
              style: tt.labelMedium!.copyWith(
                color: c.text2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
