import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_colors.dart';
import 'status_badge.dart';

class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.title,
    required this.description,
    required this.rate,
    required this.startDate,
    required this.distanceKm,
    required this.isUrgent,
    this.onTap,
  });

  final String title;
  final String description;
  final String rate;
  final String startDate;
  final double distanceKm;
  final bool isUrgent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3px urgency bar — full-width, flush at top
            if (isUrgent) Container(height: 3.h, color: AppColors.urgent),
            Padding(
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUrgent) ...[
                    const StatusBadge(variant: BadgeVariant.urgent),
                    Gap(8.h),
                  ],
                  // Title — Barlow Condensed 700 20sp
                  Text(
                    title,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.02 * 20,
                      color: AppColors.text1,
                      height: 1.1,
                    ),
                  ),
                  Gap(6.h),
                  // Description — 2-line clamp
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.barlow(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.text2,
                      height: 1.5,
                    ),
                  ),
                  Gap(12.h),
                  Divider(height: 1, color: AppColors.border),
                  Gap(12.h),
                  // Meta row: Rate | Start | Distance (action colour, pushed right)
                  Row(
                    children: [
                      _MetaCol(label: 'Rate', value: rate),
                      Gap(16.w),
                      _MetaCol(label: 'Start', value: startDate),
                      const Spacer(),
                      _MetaCol(
                        label: 'Distance',
                        value: '${distanceKm.toStringAsFixed(1)} km',
                        valueColor: AppColors.action,
                        align: CrossAxisAlignment.end,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaCol extends StatelessWidget {
  const _MetaCol({
    required this.label,
    required this.value,
    this.valueColor,
    this.align = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: GoogleFonts.barlow(
            fontSize: 10.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.text3,
          ),
        ),
        Gap(2.h),
        Text(
          value,
          style: GoogleFonts.barlowCondensed(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.text1,
          ),
        ),
      ],
    );
  }
}
