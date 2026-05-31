import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../theme/app_icons.dart';
import 'avatar_block.dart';

/// LinkedIn-style utility bar for feed surfaces: avatar (→ profile), a tappable
/// search affordance (→ the list that owns search), and a notifications bell.
///
/// Built to sit inside a **floating** [SliverAppBar.title] so it scrolls away on
/// scroll-down and snaps back on scroll-up, reclaiming vertical space mid-feed.
///
/// Brand-flat (MASTER): squared avatar (`AppRadius.avatar`), sharp search field
/// (`AppRadius.input`) — no pill, no shadow. The search box is a **button**, not
/// a live field; it routes to the surface that already owns search.
class JTopBar extends StatelessWidget {
  const JTopBar({
    super.key,
    required this.initials,
    required this.searchHint,
    required this.onSearchTap,
    required this.onAvatarTap,
    required this.onNotificationsTap,
  });

  final String initials;
  final String searchHint;
  final VoidCallback onSearchTap;
  final VoidCallback onAvatarTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        // Avatar → profile tab. 44dp tap area around the 36dp squared avatar.
        Semantics(
          button: true,
          label: 'Your profile',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAvatarTap,
            child: SizedBox(
              width: 44.r,
              height: 44.r,
              child: Center(child: AvatarBlock(initials: initials, size: 36)),
            ),
          ),
        ),
        Gap(AppSpacing.sm.w),
        // Search affordance — routes to the list that owns search.
        Expanded(
          child: Semantics(
            button: true,
            label: searchHint,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSearchTap,
              child: Container(
                height: 44.h,
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(AppRadius.input.r),
                  border: Border.all(color: c.borderStrong),
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.search,
                      size: AppIconSize.inline.r,
                      color: c.text3,
                    ),
                    Gap(AppSpacing.sm.w),
                    Expanded(
                      child: Text(
                        searchHint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium!.copyWith(color: c.text3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Gap(AppSpacing.sm.w),
        // Notifications (no dedicated tab — belongs in the utility bar).
        Semantics(
          button: true,
          label: 'Notifications',
          child: Tooltip(
            message: 'Notifications',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onNotificationsTap,
              child: Container(
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
            ),
          ),
        ),
      ],
    );
  }
}
