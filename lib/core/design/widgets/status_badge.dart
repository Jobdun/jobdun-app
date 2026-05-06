import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_colors.dart';

enum BadgeVariant { verified, available, urgent, pending, pro }

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.variant, this.label});

  final BadgeVariant variant;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final s = _spec(variant);

    return Container(
      height: 28.h,
      padding: EdgeInsets.symmetric(horizontal: 11.w),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(AppRadius.badge.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.dotColor != null) ...[
            Container(
              width: 6.r,
              height: 6.r,
              decoration: BoxDecoration(shape: BoxShape.circle, color: s.dotColor),
            ),
            Gap(5.w),
          ],
          Text(
            label ?? s.defaultLabel,
            style: GoogleFonts.barlow(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.02 * 11,
              color: s.textColor,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeSpec _spec(BadgeVariant v) => switch (v) {
    BadgeVariant.verified => const _BadgeSpec(
      bg: AppColors.verifiedBg,
      textColor: AppColors.verifiedTx,
      dotColor: AppColors.verified,
      defaultLabel: 'Licenced & Verified',
    ),
    BadgeVariant.available => const _BadgeSpec(
      bg: AppColors.availableBg,
      textColor: AppColors.availableTx,
      dotColor: AppColors.available,
      defaultLabel: 'Available now',
    ),
    BadgeVariant.urgent => const _BadgeSpec(
      bg: AppColors.urgentBg,
      textColor: AppColors.urgentTx,
      dotColor: AppColors.urgent,
      defaultLabel: 'Urgent',
    ),
    BadgeVariant.pending => const _BadgeSpec(
      bg: AppColors.actionBg,
      textColor: AppColors.actionTx,
      dotColor: AppColors.action,
      defaultLabel: 'Pending',
    ),
    BadgeVariant.pro => const _BadgeSpec(
      bg: AppColors.foundation,
      textColor: AppColors.white,
      dotColor: null,
      defaultLabel: 'Tradie Pro',
    ),
  };
}

class _BadgeSpec {
  const _BadgeSpec({
    required this.bg,
    required this.textColor,
    required this.dotColor,
    required this.defaultLabel,
  });

  final Color bg;
  final Color textColor;
  final Color? dotColor;
  final String defaultLabel;
}
