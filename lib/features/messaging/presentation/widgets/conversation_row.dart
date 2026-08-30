import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/avatar_block.dart';

/// One inbox conversation row: avatar, name (+ pin/mute glyphs), job line,
/// preview (or BLOCKED), relative time, unread badge.
///
/// Drawn on the Figma refresh (`JobDun-Screens` → Messages, node 125:6888):
/// a 40dp circular avatar, a 12dp gutter, then a three-line stack — name in
/// Inter Bold 16, the **job** in orange, the preview in tertiary ink — with
/// the relative time pinned right and vertically centred. Rows carry their
/// own 12dp vertical padding and no divider; the avatar column is the only
/// rhythm the list needs.
class ConversationRow extends StatelessWidget {
  const ConversationRow({
    super.key,
    required this.initials,
    required this.name,
    required this.preview,
    required this.time,
    required this.unreadCount,
    required this.onTap,
    this.onLongPress,
    this.jobTitle,
    this.avatarUrl,
    this.isPinned = false,
    this.isMuted = false,
    this.isBlocked = false,
  });

  final bool isPinned;
  final bool isMuted;
  final bool isBlocked;
  final String initials;
  final String name;
  final String preview;
  final String time;
  final int unreadCount;
  final String? jobTitle;
  final String? avatarUrl;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final hasUnread = unreadCount > 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w,
          vertical: 12.h,
        ),
        child: Row(
          children: [
            // ── Avatar (photo with initials fallback)
            AvatarBlock(
              initials: initials,
              imageUrl: avatarUrl,
              size: 40,
              circle: true,
            ),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: tt.titleMedium!.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: c.text1,
                          ),
                          // 2026-08-18 audit: overflow without maxLines wraps
                          // instead of ellipsizing.
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPinned) ...[
                        Gap(6.w),
                        Icon(
                          AppIcons.pinFilled,
                          size: 12.r,
                          color: c.actionInk,
                        ),
                      ],
                      if (isMuted) ...[
                        Gap(6.w),
                        Icon(AppIcons.muteFilled, size: 12.r, color: c.text3),
                      ],
                    ],
                  ),
                  if (jobTitle != null) ...[
                    Gap(AppSpacing.xs.h),
                    Text(
                      // The job is what the thread is *about* — Figma gives it
                      // the orange ink, so it reads before the preview does.
                      jobTitle!,
                      style: tt.bodyLarge!.copyWith(
                        height: 1.4,
                        color: c.actionInk,
                      ),
                      maxLines: 1, // 2026-08-18 audit
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  Gap(AppSpacing.xs.h),
                  Text(
                    isBlocked ? 'BLOCKED' : preview,
                    style: tt.bodyLarge!.copyWith(
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                      height: 1.4,
                      color: hasUnread ? c.text1 : c.text3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Gap(AppSpacing.sm.w),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: tt.bodySmall!.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1.0,
                    color: hasUnread ? c.actionInk : c.text3,
                  ),
                ),
                if (hasUnread) ...[
                  Gap(6.h),
                  Container(
                    width: 20.r,
                    height: 20.r,
                    decoration: BoxDecoration(
                      color: c.action,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: tt.labelSmall!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.onAction, // dark-on-orange — 6.37:1
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
