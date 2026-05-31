import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/theme/app_icons.dart';

/// Notifications — design-system placeholder / zero-state. Reached from the
/// header bell on `/home`. Follows MASTER: dark surface, an `AppIcons` glyph at
/// `AppIconSize.hero`, declarative copy (no "Yay!"/"You're all set!"), and
/// tokenised spacing/type. Doubles as the real empty state once the feed ships.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('NOTIFICATIONS')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88.r,
                  height: 88.r,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(
                    AppIcons.notification,
                    size: AppIconSize.hero.r,
                    color: c.text3,
                  ),
                ),
                Gap(AppSpacing.lg.h),
                Text(
                  'NO NOTIFICATIONS YET',
                  style: tt.headlineSmall!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                Gap(AppSpacing.sm.h),
                Text(
                  'Job activity, application updates, and verification notices '
                  'will show up here.',
                  style: tt.bodyMedium!.copyWith(color: c.text2),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
