import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:jobdun/core/theme/app_icons.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/jobdun_logo.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';

/// Home header from the Figma **Homepage** section (node `64:2971`): the
/// JOBDUN lockup on the left, notification bell + settings gear on the right.
///
/// Used by BOTH roles (builder node 64:2971, tradie node 134:9625). It
/// replaced the old avatar-and-search status bar, which led with the user
/// rather than the brand and duplicated the tradie's open-for-work state that
/// now has its own card in the body.
///
/// The unread badge is kept even though the mock draws a bare bell — dropping
/// it would remove the screen's only unread signal. It reuses the existing
/// bar's `c.action` badge so the two headers agree while both are in the app.
class HomeBrandHeader extends ConsumerWidget {
  const HomeBrandHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(
      notificationsControllerProvider.select((s) => s.unreadCount),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          const JobdunLogo(variant: LogoVariant.full, height: 32),
          const Spacer(),
          _HeaderAction(
            icon: AppIcons.notification,
            semanticLabel: unreadCount > 0
                ? 'Notifications, $unreadCount unread'
                : 'Notifications',
            badgeCount: unreadCount,
            onTap: () => context.push('/notifications'),
          ),
          Gap(8.w),
          _HeaderAction(
            icon: AppIcons.settings,
            semanticLabel: 'Settings',
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}

/// One 32dp glyph in the header, inside a 48dp hit box.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkResponse(
        onTap: onTap,
        radius: 24.r,
        child: SizedBox(
          width: 48.w,
          height: 48.h,
          child: Center(
            child: badges.Badge(
              showBadge: badgeCount > 0,
              badgeStyle: badges.BadgeStyle(
                badgeColor: c.action,
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                shape: badges.BadgeShape.square,
                borderRadius: BorderRadius.circular(8.r),
              ),
              badgeContent: Text(
                badgeCount > 9 ? '9+' : '$badgeCount',
                style: tt.labelSmall!.copyWith(
                  color: c.onAction,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Icon(icon, size: 32.r, color: c.text1),
            ),
          ),
        ),
      ),
    );
  }
}
