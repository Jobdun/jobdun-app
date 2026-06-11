import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/avatar_block.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

/// Option A navigation: the avatar's account sheet — the single front door to
/// everything that used to live behind the (removed) Profile tab. Work stays
/// in the bottom bar; identity/plumbing lives one avatar tap away (M3
/// account-surface pattern).
Future<void> showAccountSheet(BuildContext context) {
  return showJSheet<void>(
    context: context,
    expand: false,
    backgroundColor: context.c.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _AccountSheetBody(),
  );
}

class _AccountSheetBody extends ConsumerWidget {
  const _AccountSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final profile = ref.watch(
      profileControllerProvider.select((s) => s.profile),
    );
    final isTrade = ref.watch(
      authControllerProvider.select((s) => s.role == UserRole.trade),
    );
    final name = (profile?.displayName ?? '').trim();

    void go(String route) {
      Navigator.of(context).pop();
      context.push(route);
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Gap(16.h),
            Row(
              children: [
                AvatarBlock(
                  initials: name.isEmpty ? '?' : name[0].toUpperCase(),
                  imageUrl: profile?.avatarUrl,
                  size: 48,
                  circle: true,
                ),
                Gap(12.w),
                Expanded(
                  child: Text(
                    name.isEmpty ? 'Your account' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleLarge!.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            Gap(8.h),
            Divider(color: c.border, height: 16.h),
            _AccountRow(
              icon: AppIcons.user,
              label: 'My profile',
              onTap: () => go('/profile'),
            ),
            _AccountRow(
              icon: AppIcons.shield,
              label: isTrade ? 'Credentials' : 'Verification',
              onTap: () => go('/verification/wizard'),
            ),
            _AccountRow(
              icon: AppIcons.edit,
              label: 'Edit profile',
              onTap: () => go('/profile/edit'),
            ),
            if (isTrade)
              _AccountRow(
                icon: AppIcons.calendar,
                label: 'Availability schedule',
                // go (not push): /schedule is the Schedule TAB — switching the
                // branch keeps the dock visible; a push would render it
                // dockless with no back affordance.
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/schedule');
                },
              ),
            _AccountRow(
              icon: AppIcons.settings,
              label: 'Settings',
              onTap: () => go('/settings'),
            ),
            _AccountRow(
              icon: AppIcons.notification,
              label: 'Notification settings',
              onTap: () => go('/settings/notifications'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final color = c.text1;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 48.h),
        child: Row(
          children: [
            Icon(icon, size: AppIconSize.md.r, color: color),
            Gap(12.w),
            Expanded(
              child: Text(label, style: tt.titleSmall!.copyWith(color: color)),
            ),
            Icon(
              AppIcons.chevronRight,
              size: AppIconSize.inline.r,
              color: c.text3,
            ),
          ],
        ),
      ),
    );
  }
}
