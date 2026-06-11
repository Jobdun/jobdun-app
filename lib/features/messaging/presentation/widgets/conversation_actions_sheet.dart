import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';

/// What the user picked on the long-press conversation sheet; the inbox page
/// performs the action (same contract as the thread's message-actions sheet).
enum ConversationAction { pin, markUnread, mute, archive, block, report }

/// Long-press actions for an inbox conversation (Phase D, revised 2026-06-12:
/// replaced the left/right swipe panes — five squeezed swipe labels were hard
/// to read, and long-press → sheet matches the thread's message actions).
class ConversationActionsSheet extends StatelessWidget {
  const ConversationActionsSheet({
    super.key,
    required this.otherName,
    required this.isPinned,
    required this.isMuted,
    this.jobTitle,
  });

  final String otherName;
  final bool isPinned;
  final bool isMuted;
  final String? jobTitle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 4.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  otherName.toUpperCase(),
                  style: tt.titleMedium!.copyWith(
                    color: c.text1,
                    letterSpacing: 0.6,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (jobTitle != null) ...[
                  Gap(2.h),
                  Text(
                    jobTitle!,
                    style: tt.bodySmall!.copyWith(color: c.text3),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Gap(8.h),
          _ActionRow(
            icon: isPinned ? AppIcons.pinFilled : AppIcons.pin,
            label: isPinned ? 'UNPIN' : 'PIN TO TOP',
            onTap: () => Navigator.pop(context, ConversationAction.pin),
          ),
          _ActionRow(
            icon: AppIcons.email,
            label: 'MARK AS UNREAD',
            onTap: () => Navigator.pop(context, ConversationAction.markUnread),
          ),
          _ActionRow(
            icon: isMuted ? AppIcons.muteFilled : AppIcons.mute,
            label: isMuted ? 'UNMUTE' : 'MUTE',
            onTap: () => Navigator.pop(context, ConversationAction.mute),
          ),
          _ActionRow(
            icon: AppIcons.archive,
            label: 'ARCHIVE',
            onTap: () => Navigator.pop(context, ConversationAction.archive),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
            child: Divider(height: 1, color: c.border),
          ),
          _ActionRow(
            icon: AppIcons.block,
            label: 'BLOCK ${otherName.toUpperCase()}',
            destructive: true,
            onTap: () => Navigator.pop(context, ConversationAction.block),
          ),
          _ActionRow(
            icon: AppIcons.warning,
            label: 'REPORT',
            destructive: true,
            onTap: () => Navigator.pop(context, ConversationAction.report),
          ),
          Gap(12.h),
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
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 13.h),
        child: Row(
          children: [
            Icon(icon, size: AppIconSize.md.r, color: color),
            Gap(14.w),
            Expanded(
              child: Text(
                label,
                style: tt.titleSmall!.copyWith(
                  color: color,
                  letterSpacing: 0.4,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
