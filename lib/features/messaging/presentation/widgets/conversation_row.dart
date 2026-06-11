import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/avatar_block.dart';

/// One inbox conversation row: avatar, name (+ pin/mute glyphs), job line,
/// preview (or BLOCKED), relative time, unread badge. Extracted from
/// messages_page.dart for the file-size budget (Phase D).
class ConversationRow extends StatelessWidget {
  const ConversationRow({
    super.key,
    required this.initials,
    required this.name,
    required this.preview,
    required this.time,
    required this.unreadCount,
    required this.onTap,
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

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final hasUnread = unreadCount > 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar (photo with initials fallback)
            AvatarBlock(
              initials: initials,
              imageUrl: avatarUrl,
              size: 46,
              circle: true,
            ),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: tt.titleMedium!.copyWith(
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: c.text1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPinned) ...[
                        Gap(6.w),
                        Icon(AppIcons.pinFilled, size: 12.r, color: c.action),
                      ],
                      if (isMuted) ...[
                        Gap(6.w),
                        Icon(AppIcons.muteFilled, size: 12.r, color: c.text3),
                      ],
                      Gap(8.w),
                      Text(
                        time,
                        style: tt.bodySmall!.copyWith(
                          fontWeight: FontWeight.w400,
                          color: hasUnread ? c.action : c.text3,
                        ),
                      ),
                    ],
                  ),
                  if (jobTitle != null) ...[
                    Gap(2.h),
                    Text(
                      jobTitle!,
                      style: tt.bodySmall!.copyWith(
                        fontWeight: FontWeight.w500,
                        color: c.text2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  Gap(3.h),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isBlocked ? 'BLOCKED' : preview,
                          style: tt.bodyMedium!.copyWith(
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: hasUnread ? c.text1 : c.text3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        Gap(8.w),
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
          ],
        ),
      ),
    );
  }
}
