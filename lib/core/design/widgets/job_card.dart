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
    this.onApply,
  });

  final String title;
  final String description;
  final String rate;
  final String startDate;
  final double distanceKm;
  final bool isUrgent;
  final VoidCallback? onTap;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(color: c.border),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUrgent) Container(height: 3.h, color: c.urgent),
            Padding(
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isUrgent) ...[
                              const StatusBadge(variant: BadgeVariant.urgent),
                              Gap(8.h),
                            ],
                            Text(
                              title,
                              style: GoogleFonts.oswald(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: c.text1,
                                height: 1.1,
                              ),
                            ),
                            Gap(4.h),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.openSans(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w400,
                                color: c.text2,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onApply != null) ...[
                        Gap(12.w),
                        GestureDetector(
                          onTap: onApply,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              color: c.action,
                              borderRadius: BorderRadius.circular(AppRadius.btn.r),
                            ),
                            child: Text(
                              'APPLY NOW',
                              style: GoogleFonts.openSans(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Gap(12.h),
                  Container(height: 1, color: c.border),
                  Gap(12.h),
                  Row(
                    children: [
                      _MetaCol(label: 'RATE',     value: rate,     c: c),
                      Gap(16.w),
                      _MetaCol(label: 'START',    value: startDate, c: c),
                      const Spacer(),
                      _MetaCol(
                        label: 'DISTANCE',
                        value: '${distanceKm.toStringAsFixed(1)} km',
                        c: c,
                        valueColor: c.action,
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
    required this.c,
    this.valueColor,
    this.align = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final JColors c;
  final Color? valueColor;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: GoogleFonts.openSans(
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: c.text3,
          ),
        ),
        Gap(2.h),
        Text(
          value,
          style: GoogleFonts.oswald(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: valueColor ?? c.text1,
          ),
        ),
      ],
    );
  }
}
