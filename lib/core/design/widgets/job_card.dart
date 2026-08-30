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
  // v2 verification — small chip next to RATE/START/DISTANCE showing whether
  // the poster (builder) has an ABN-verified status. `unknown` renders nothing.
  final PosterVerificationStatus posterVerificationStatus;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    // Figma `JobDun-Screens` → Find (node 140:13778): a 16dp-radius card on a
    // hairline, 16dp padding, and a 16dp rhythm between its three blocks —
    // headline, rule, meta row. Urgency reads off the pill alone now; the old
    // 3dp red strip above it said the same thing twice.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
          border: Border.all(color: c.border),
        ),
        clipBehavior: Clip.hardEdge,
        padding: EdgeInsets.all(AppSpacing.md.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUrgent) ...[
              const StatusBadge(variant: BadgeVariant.urgent),
              Gap(AppSpacing.md.h),
            ],
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.titleMedium!.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: c.text1,
              ),
            ),
            Gap(AppSpacing.sm.h),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.bodyLarge!.copyWith(height: 1.4, color: c.text1),
            ),
            Gap(AppSpacing.md.h),
            Container(height: 1, color: c.border),
            Gap(AppSpacing.md.h),
            // Rate · Start · Distance. Start takes the slack so the distance
            // column stays pinned right and the row never reflows between
            // cards.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetaCol(label: 'Rate', value: rate),
                Gap(AppSpacing.md.w),
                Expanded(
                  child: _MetaCol(label: 'Start', value: startDate),
                ),
                // Null = distance unknown (the home mini-feed runs no geo
                // query) — the column hides rather than lying with "0.0 km".
                if (distanceKm != null) ...[
                  Gap(AppSpacing.md.w),
                  _MetaCol(
                    label: 'Distance',
                    value: '${distanceKm!.toStringAsFixed(1)} km',
                    align: CrossAxisAlignment.end,
                  ),
                ],
              ],
            ),
            if (posterVerificationStatus !=
                PosterVerificationStatus.unknown) ...[
              Gap(AppSpacing.sm.h),
              JobCardPosterBadge(status: posterVerificationStatus),
            ],
          ],
        ),
      ),
    );
  }
}

/// One label-over-value cell in the card's meta row (Figma node 140:13784).
/// Label and value share the 16dp size; weight carries the hierarchy.
class _MetaCol extends StatelessWidget {
  const _MetaCol({
    required this.label,
    required this.value,
    this.align = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.bodyLarge!.copyWith(height: 1.4, color: c.text1),
        ),
        Gap(AppSpacing.xs.h),
        // Tabular figures so rates/dates/distances align and don't jitter
        // between cards.
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.numeric(
            tt.titleMedium!,
          ).copyWith(fontWeight: FontWeight.w700, height: 1.2, color: c.text1),
        ),
      ],
    );
  }
}
