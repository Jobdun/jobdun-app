import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';

class BottomSheetHeader extends StatelessWidget {
  const BottomSheetHeader({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          if (title != null) ...[
            Gap(AppSpacing.md.h),
            Text(
              title!.toUpperCase(),
              style: Theme.of(
                context,
              ).textTheme.titleLarge!.copyWith(color: c.text1),
            ),
          ],
        ],
      ),
    );
  }
}
