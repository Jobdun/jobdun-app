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
    final c = context.c;
    final s = _spec(c, variant);

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
              letterSpacing: 0.5,
              color: s.textColor,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeSpec _spec(JColors c, BadgeVariant v) => switch (v) {
    BadgeVariant.verified => _BadgeSpec(
      bg: c.verifiedBg, textColor: c.verifiedTx, dotColor: c.verified,
      defaultLabel: 'Licenced & Verified',
    ),
    BadgeVariant.available => _BadgeSpec(
      bg: c.availableBg, textColor: c.availableTx, dotColor: c.available,
      defaultLabel: 'Available now',
    ),
    BadgeVariant.urgent => _BadgeSpec(
      bg: c.urgentBg, textColor: c.urgentTx, dotColor: c.urgent,
      defaultLabel: 'Urgent',
    ),
    BadgeVariant.pending => _BadgeSpec(
      bg: c.actionBg, textColor: c.actionTx, dotColor: c.action,
      defaultLabel: 'Pending',
    ),
    BadgeVariant.pro => _BadgeSpec(
      bg: c.surfaceRaised, textColor: c.text1, dotColor: null,
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
