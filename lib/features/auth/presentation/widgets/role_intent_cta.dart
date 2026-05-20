import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/design/colors.dart';

// Role-as-entry-point CTA. Two of these stack on /login under the
// "NEW TO JOBDUN?" divider, each deep-linking to /register?role=… so the
// step-1 picker can be skipped. Modeled on Hipages' "Get Quotes" /
// "Join as a Tradie" pattern — pick the side of the marketplace first.
class RoleIntentCta extends StatelessWidget {
  const RoleIntentCta({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '$label. $subtitle',
      child: Material(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.btn.r),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: c.action.withValues(alpha: 0.12),
          highlightColor: c.action.withValues(alpha: 0.06),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w,
              vertical: 14.h,
            ),
            child: Row(
              children: [
                Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppRadius.avatar.r),
                  ),
                  child: Icon(icon, size: 18.r, color: c.action),
                ),
                Gap(AppSpacing.md.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: tt.labelLarge!.copyWith(
                          color: c.text1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Gap(2.h),
                      Text(
                        subtitle,
                        style: tt.bodySmall!.copyWith(
                          color: c.text3,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Gap(AppSpacing.sm.w),
                Icon(Iconsax.arrow_right_3, size: 18.r, color: c.text3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
