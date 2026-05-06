import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:iconsax/iconsax.dart';

import '../../app/theme/app_colors.dart';

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final bg     = isError ? AppColors.urgentBg   : AppColors.verifiedBg;
    final border = isError ? AppColors.urgent      : AppColors.verified;
    final icon   = isError ? Iconsax.warning_2     : Iconsax.tick_circle;
    final color  = isError ? AppColors.urgent      : AppColors.verified;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.chip.r),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16.r, color: color),
          Gap(8.w),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.text1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
