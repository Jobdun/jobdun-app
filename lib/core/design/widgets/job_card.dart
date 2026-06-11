import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../features/verification/presentation/widgets/job_card_poster_badge.dart';
import 'status_badge.dart';

class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.title,
    required this.description,
    required this.rate,
    required this.startDate,
    this.distanceKm,
    required this.isUrgent,
    this.onTap,
    this.onApply,
    this.posterVerificationStatus = PosterVerificationStatus.unknown,
  });

  final String title;
  final String description;
  final String rate;
  final String startDate;

  /// Null = distance unknown (home mini-feed has no geo query) — the chip
  /// hides instead of lying with a hardcoded "0.0 km".
  final double? distanceKm;
  final bool isUrgent;
  final VoidCallback? onTap;
  final VoidCallback? onApply;
  // v2 verification — small chip next to RATE/START/DISTANCE showing whether
  // the poster (builder) has an ABN-verified status. `unknown` renders nothing.
  final PosterVerificationStatus posterVerificationStatus;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

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
              padding: EdgeInsets.all(AppSpacing.md.r),
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              // titleLarge = MASTER "card header" role (Oswald
                              // 600). Was headlineSmall (a sub-section size) —
                              // too loud for a feed row and it crowded the meta.
                              style: tt.titleLarge!.copyWith(
                                fontWeight: FontWeight.w700,
                                color: c.text1,
                                height: 1.2,
                              ),
                            ),
                            Gap(4.h),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodyMedium!.copyWith(
                                color: c.text2,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onApply != null) ...[
                        Gap(12.w),
                        Semantics(
                          button: true,
                          label: 'Apply to $title',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onApply,
                            child: Container(
                              constraints: BoxConstraints(minHeight: 44.h),
                              alignment: Alignment.center,
                              padding: EdgeInsets.symmetric(horizontal: 14.w),
                              decoration: BoxDecoration(
                                color: c.action,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.btn.r,
                                ),
                              ),
                              // Buttons stay ALL CAPS — that's the brand
                              // (MASTER). labelLarge is the canonical button
                              // role (Oswald 700); no off-scale .sp override.
                              child: Text(
                                'APPLY NOW',
                                style: tt.labelLarge!.copyWith(
                                  color: c.onAction,
                                ),
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
                      _MetaCol(label: 'Rate', value: rate, c: c, tt: tt),
                      Gap(AppSpacing.md.w),
                      _MetaCol(label: 'Start', value: startDate, c: c, tt: tt),
                      const Spacer(),
                      // Distance is metadata, not a CTA — neutral text, not
                      // orange (MASTER §54: orange is CTA/critical only).
                      if (distanceKm != null)
                        _MetaCol(
                          label: 'Distance',
                          value: '${distanceKm!.toStringAsFixed(1)} km',
                          c: c,
                          tt: tt,
                          align: CrossAxisAlignment.end,
                        ),
                    ],
                  ),
                  if (posterVerificationStatus !=
                      PosterVerificationStatus.unknown) ...[
                    Gap(8.h),
                    JobCardPosterBadge(status: posterVerificationStatus),
                  ],
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
    required this.tt,
    this.align = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final JColors c;
  final TextTheme tt;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.labelMedium!.copyWith(color: c.text3),
        ),
        Gap(2.h),
        // titleMedium (emphasised body, Open Sans 600) + tabular figures so
        // rates/dates/distances align and don't jitter. The Oswald title above
        // carries the hierarchy through font contrast, not raw size.
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.numeric(
            tt.titleMedium!,
          ).copyWith(fontWeight: FontWeight.w700, color: c.text1),
        ),
      ],
    );
  }
}
