part of 'applicant_detail_page.dart';

// Which bottom-bar action is currently in flight (null = idle).
enum _BarAction { message, shortlist, reject, hire }

// Bottom action bar — MESSAGE is always primary; the state-specific action
// (shortlist / hire) leads when it matters; reject stays available.
//
// 2026-08-18 audit (#5, #9): stateful with a single in-flight guard — two
// fast taps on HIRE used to double-pop the navigator (dismissing the
// applicants list too), and double-tapping MESSAGE pushed the thread twice.
// While any action runs, all buttons disable and the tapped one shows its
// loading spinner.
class _ActionBar extends StatefulWidget {
  const _ActionBar({
    required this.status,
    required this.onMessage,
    required this.onShortlist,
    required this.onReject,
    required this.onHire,
  });

  final ApplicationStatus status;
  final Future<void> Function() onMessage;
  final Future<void> Function() onShortlist;
  final Future<void> Function() onReject;
  final Future<void> Function() onHire;

  @override
  State<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends State<_ActionBar> {
  _BarAction? _busy;

  Future<void> _run(_BarAction action, Future<void> Function() task) async {
    if (_busy != null) return;
    setState(() => _busy = action);
    try {
      await task();
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  VoidCallback? _guarded(_BarAction action, Future<void> Function() task) =>
      _busy != null ? null : () => _run(action, task);

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    // Figma `JobDun-Screens` → Applicant (node 124:5957): the state action and
    // its refusal share the top row; MESSAGE gets its own full-width row
    // beneath so the label is never squeezed. All three at 48dp.
    final messageSecondary = JButton(
      label: 'Message',
      icon: AppIcons.send,
      variant: JButtonVariant.outline,
      isLoading: _busy == _BarAction.message,
      onPressed: _guarded(_BarAction.message, widget.onMessage),
    );
    final reject = JButton(
      label: 'Reject',
      variant: JButtonVariant.dangerOutline,
      isLoading: _busy == _BarAction.reject,
      onPressed: _guarded(_BarAction.reject, widget.onReject),
    );

    final Widget body;
    if (widget.status == ApplicationStatus.pending) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: JButton(
                  label: 'Shortlist',
                  isLoading: _busy == _BarAction.shortlist,
                  onPressed: _guarded(_BarAction.shortlist, widget.onShortlist),
                ),
              ),
              Gap(AppSpacing.sm.w),
              Expanded(child: reject),
            ],
          ),
          Gap(AppSpacing.md.h),
          Row(children: [Expanded(child: messageSecondary)]),
        ],
      );
    } else if (widget.status == ApplicationStatus.shortlisted) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: JButton(
                  label: 'Hire this tradie',
                  variant: JButtonVariant.successOutline,
                  isLoading: _busy == _BarAction.hire,
                  onPressed: _guarded(_BarAction.hire, widget.onHire),
                ),
              ),
              Gap(AppSpacing.sm.w),
              Expanded(child: reject),
            ],
          ),
          Gap(AppSpacing.md.h),
          Row(children: [Expanded(child: messageSecondary)]),
        ],
      );
    } else {
      // hired / rejected / withdrawn / declined — terminal: MESSAGE is now the
      // sole action, so it leads as the primary CTA.
      body = Row(
        children: [
          Expanded(
            child: JButton(
              label: 'Message',
              icon: AppIcons.send,
              isLoading: _busy == _BarAction.message,
              onPressed: _guarded(_BarAction.message, widget.onMessage),
            ),
          ),
        ],
      );
    }

    return Container(
      color: c.card,
      padding: EdgeInsets.all(AppSpacing.md.r),
      child: body,
    );
  }
}
