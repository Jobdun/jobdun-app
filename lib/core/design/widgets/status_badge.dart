import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';

enum BadgeVariant { verified, available, urgent, warning, pending, pro }

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.variant, this.label});

  final BadgeVariant variant;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final s = _spec(c, variant);

    // Figma draws every status as a fully-rounded pill with an 8dp dot and a
    // 12px regular label (e.g. Find → node 140:13794). The old 4dp-radius
    // 28dp-tall chip predates that vocabulary.
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(AppRadius.btn.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.dotColor != null) ...[
            Container(
              width: 8.r,
              height: 8.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.textColor,
              ),
            ),
            Gap(AppSpacing.xs.w),
          ],
          Flexible(
            child: Text(
              label ?? s.defaultLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall!.copyWith(
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
                height: 1.0,
                color: s.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _BadgeSpec _spec(JColors c, BadgeVariant v) => switch (v) {
    BadgeVariant.verified => _BadgeSpec(
      bg: c.verifiedBg,
      textColor: c.verifiedTx,
      dotColor: c.verified,
      defaultLabel: 'Licenced & Verified',
    ),
    BadgeVariant.available => _BadgeSpec(
      bg: c.availableBg,
      textColor: c.availableTx,
      dotColor: c.available,
      defaultLabel: 'Available now',
    ),
    BadgeVariant.urgent => _BadgeSpec(
      bg: c.urgentBg,
      textColor: c.urgentTx,
      dotColor: c.urgent,
      defaultLabel: 'Urgent',
    ),
    BadgeVariant.warning => _BadgeSpec(
      bg: c.warningBg,
      textColor: c.warningTx,
      dotColor: c.warning,
      defaultLabel: 'Filled',
    ),
    BadgeVariant.pending => _BadgeSpec(
      bg: c.actionBg,
      textColor: c.actionTx,
      dotColor: c.action,
      defaultLabel: 'Pending',
    ),
    BadgeVariant.pro => _BadgeSpec(
      bg: c.surfaceRaised,
      textColor: c.text1,
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
