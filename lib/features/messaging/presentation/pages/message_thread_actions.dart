part of 'message_thread_page.dart';

// Long-press message actions (Phase C). The bottom sheet returns the chosen
// action; the page performs it. Split into a `part` so the page + widgets stay
// under the file-size budget. Single-use, co-located with their caller.
//
// This increment wires Copy + Unsend. Reply / React / Edit rows land in the
// next increments (they need the reactions table + reply_to_id + edit window).
enum _MessageAction { copy, unsend }

class _MessageActionsSheet extends StatelessWidget {
  const _MessageActionsSheet({required this.isMine});

  // Unsend is only offered on your own messages (RLS enforces it server-side).
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Gap(AppSpacing.sm.h),
          _ActionRow(
            icon: Icons.content_copy,
            label: 'Copy',
            onTap: () => Navigator.pop(context, _MessageAction.copy),
          ),
          if (isMine)
            _ActionRow(
              icon: AppIcons.trash,
              label: 'Unsend',
              destructive: true,
              onTap: () => Navigator.pop(context, _MessageAction.unsend),
            ),
          Gap(AppSpacing.sm.h),
          Divider(height: 1, color: c.border),
          _ActionRow(
            icon: AppIcons.close,
            label: 'Cancel',
            onTap: () => Navigator.pop(context),
          ),
          Gap(AppSpacing.sm.h),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final color = destructive ? c.urgent : c.text1;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, size: AppIconSize.md.r, color: color),
            Gap(16.w),
            Text(
              label,
              style: tt.titleMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
