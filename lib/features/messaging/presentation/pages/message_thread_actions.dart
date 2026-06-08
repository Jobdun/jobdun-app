part of 'message_thread_page.dart';

// Long-press message actions (Phase C), Messenger-style: a horizontal emoji
// reaction row on top, then a horizontal row of action buttons. The sheet
// returns the chosen result; the page performs it. Split into a `part` so the
// page + widgets stay under the file-size budget.
enum _MessageAction { copy, unsend, react }

class _SheetResult {
  const _SheetResult.copy() : action = _MessageAction.copy, emoji = null;
  const _SheetResult.unsend() : action = _MessageAction.unsend, emoji = null;
  const _SheetResult.react(this.emoji) : action = _MessageAction.react;

  final _MessageAction action;
  final String? emoji;
}

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
          // ── Reaction row (horizontal, tap to react)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final emoji in kReactionEmojis)
                  _EmojiButton(
                    emoji: emoji,
                    onTap: () =>
                        Navigator.pop(context, _SheetResult.react(emoji)),
                  ),
              ],
            ),
          ),
          Gap(AppSpacing.sm.h),
          Divider(height: 1, color: c.border),
          Gap(AppSpacing.sm.h),
          // ── Action row (horizontal icon buttons)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                icon: Icons.content_copy,
                label: 'Copy',
                onTap: () => Navigator.pop(context, const _SheetResult.copy()),
              ),
              if (isMine)
                _ActionButton(
                  icon: AppIcons.trash,
                  label: 'Unsend',
                  destructive: true,
                  onTap: () =>
                      Navigator.pop(context, const _SheetResult.unsend()),
                ),
            ],
          ),
          Gap(AppSpacing.md.h),
        ],
      ),
    );
  }
}

// A circular tappable emoji in the reaction row.
class _EmojiButton extends StatelessWidget {
  const _EmojiButton({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 46.r,
        height: 46.r,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}

// A vertical icon-over-label button used in the horizontal action row.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
      borderRadius: BorderRadius.circular(AppRadius.card.r),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46.r,
              height: 46.r,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: AppIconSize.md.r, color: color),
            ),
            Gap(6.h),
            Text(
              label,
              style: tt.labelMedium!.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
