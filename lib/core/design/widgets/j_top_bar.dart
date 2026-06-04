import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../theme/app_icons.dart';
import 'avatar_block.dart';

/// Home top bar — V1 "greeting + actions": a time-of-day greeting + the user's
/// name (tap → profile), a role chip, and a notifications bell. Search lives in
/// the feed/list surfaces, not here.
///
/// Sits inside a **floating** [SliverAppBar.title] so it scrolls away on
/// scroll-down and snaps back on scroll-up.
class JTopBar extends StatelessWidget {
  const JTopBar({
    super.key,
    required this.displayName,
    required this.initials,
    required this.onAvatarTap,
    required this.onNotificationsTap,
    this.roleLabel,
    this.avatarUrl,
    this.hasUnread = false,
  });

  final String displayName;
  final String initials;
  final String? roleLabel;
  final String? avatarUrl;
  final bool hasUnread;
  final VoidCallback onAvatarTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        // Avatar (photo or initials) → profile.
        Semantics(
          button: true,
          label: 'Your profile',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAvatarTap,
            child: AvatarBlock(
              initials: initials,
              imageUrl: avatarUrl,
              size: 44,
              circle: true,
            ),
          ),
        ),
        Gap(AppSpacing.md.w),
        // Greeting + name (also taps through to profile).
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAvatarTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _greeting(),
                  style: tt.bodySmall!.copyWith(color: c.text3),
                ),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleLarge!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text1,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (roleLabel != null) ...[
          Gap(AppSpacing.sm.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.chip.r),
            ),
            child: Text(
              roleLabel!,
              style: tt.labelSmall!.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: c.text2,
              ),
            ),
          ),
        ],
        Gap(AppSpacing.sm.w),
        // Notifications bell (unread dot).
        Semantics(
          button: true,
          label: 'Notifications',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onNotificationsTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44.r,
                  height: 44.r,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppRadius.avatar.r),
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(
                    AppIcons.notification,
                    size: AppIconSize.nav.r,
                    color: c.text2,
                  ),
                ),
                if (hasUnread)
                  Positioned(
                    top: 10.r,
                    right: 11.r,
                    child: Container(
                      width: 9.r,
                      height: 9.r,
                      decoration: BoxDecoration(
                        color: c.action,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
