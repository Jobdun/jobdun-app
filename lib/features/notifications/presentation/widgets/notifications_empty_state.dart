import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/theme/app_icons.dart';

/// Zero-state for the notifications feed. Follows MASTER: dark surface, an
/// `AppIcons` glyph at `AppIconSize.hero`, declarative copy (no "Yay!").
class NotificationsEmptyState extends StatelessWidget {
  const NotificationsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Center(
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
    );
  }
}
