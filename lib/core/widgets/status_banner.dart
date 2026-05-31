import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../app/theme/app_colors.dart';

class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bg = isError ? c.urgentBg : c.verifiedBg;
    final border = isError ? c.urgent : c.verified;
    final icon = isError ? AppIcons.warning : AppIcons.successCircle;
    final color = isError ? c.urgent : c.verified;
    final tx = isError ? c.urgentTx : c.verifiedTx;

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
          Icon(icon, size: AppIconSize.inline.r, color: color),
          Gap(8.w),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tx),
            ),
          ),
        ],
      ),
    );
  }
}
