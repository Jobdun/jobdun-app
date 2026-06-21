import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/utils/app_date_utils.dart';
import '../../domain/entities/app_notification.dart';

/// One notification row. Unread rows carry an orange accent strip and a bolder
/// title; read rows sit muted on the background. Tap target ≥ 48dp.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final unread = !notification.isRead;

    return Material(
      color: unread ? c.surface : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: 64.h),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg.w,
            vertical: AppSpacing.md.h,
          ),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: unread ? c.action : Colors.transparent,
                width: 3.w,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CategoryGlyph(category: notification.category, unread: unread),
              Gap(AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall!.copyWith(
                        color: c.text1,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    if (notification.body.isNotEmpty) ...[
                      Gap(AppSpacing.xs.h),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium!.copyWith(color: c.text2),
                      ),
                    ],
                  ],
                ),
              ),
              Gap(AppSpacing.md.w),
              Text(
                AppDateUtils.formatRelative(notification.createdAt),
                style: tt.bodySmall!.copyWith(
                  color: unread ? c.actionInk : c.text3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryGlyph extends StatelessWidget {
  const _CategoryGlyph({required this.category, required this.unread});

  final NotificationCategory category;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 40.r,
      height: 40.r,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: unread ? c.surfaceRaised : c.surface,
        shape: BoxShape.circle,
        border: Border.all(color: c.border),
      ),
      child: Icon(
        _iconFor(category),
        size: AppIconSize.inline.r,
        color: unread ? c.text1 : c.text2,
      ),
    );
  }

  IconData _iconFor(NotificationCategory category) => switch (category) {
    NotificationCategory.job => AppIcons.briefcase,
    NotificationCategory.message => AppIcons.chat,
    NotificationCategory.application => AppIcons.appliedOutline,
    NotificationCategory.quote => AppIcons.budget,
    NotificationCategory.verification => AppIcons.policy,
    NotificationCategory.review => AppIcons.star,
    NotificationCategory.announcement => AppIcons.info,
    NotificationCategory.other => AppIcons.notification,
  };
}
