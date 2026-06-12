import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/design/colors.dart';

/// All-caps section eyebrow for the notifications list (NEW / EARLIER).
class NotificationSectionHeader extends StatelessWidget {
  const NotificationSectionHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg.w,
        AppSpacing.xl.h,
        AppSpacing.lg.w,
        AppSpacing.sm.h,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall!.copyWith(color: c.text3),
      ),
    );
  }
}
