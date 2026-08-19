import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import 'avatar_block.dart';

class TradieCard extends StatelessWidget {
  const TradieCard({
    super.key,
    required this.name,
    required this.trade,
    required this.suburb,
    this.rating,
    required this.jobCount,
    required this.isVerified,
    required this.isAvailable,
    required this.distanceKm,
    required this.initials,
    this.onTap,
    this.avatarColor,
  });

  final String name;
  final String trade;
  final String suburb;

  /// Null = unrated. The rating block is hidden entirely rather than showing
  /// a hollow "0.0 /5" (2026-08-18 audit — mirrors profile_rating_block).
  final double? rating;
  final int jobCount;
  final bool isVerified;
  final bool isAvailable;
  final double distanceKm;
  final String initials;
  final VoidCallback? onTap;
  final Color? avatarColor;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final isOffline = !isAvailable;

    return Opacity(
      opacity: isOffline ? 0.45 : 1.0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(AppSpacing.md.r),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AvatarBlock(initials: initials, size: 44, bg: avatarColor),
                  Gap(12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: tt.titleMedium!.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: c.text1,
                                ),
                                // 2026-08-18 audit: overflow without maxLines
                                // wraps instead of ellipsizing.
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (rating != null)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    rating!.toStringAsFixed(1),
                                    // titleLarge (Archivo) + tabular figures —
                                    // an on-scale role, not an 18.sp override.
                                    style: AppTypography.numeric(tt.titleLarge!)
                                        .copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: c.text1,
                                          height: 1,
                                        ),
                                  ),
                                  Text(
                                    '/5',
                                    style: tt.bodySmall!.copyWith(
                                      color: c.text3,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        Gap(2.h),
                        Text(
                          '$trade · $suburb',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium!.copyWith(color: c.text2),
                        ),
                        Gap(2.h),
                        Text(
                          // 2026-08-18 audit: pluralise — "1 jobs completed".
                          jobCount == 1
                              ? '1 job completed'
                              : '$jobCount jobs completed',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall!.copyWith(color: c.text3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Divider(height: 1, color: c.border),
              ),
              Row(
                children: [
                  Container(
                    width: 6.r,
                    height: 6.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOffline ? c.text3 : c.verified,
                    ),
                  ),
                  Gap(AppSpacing.sm.w),
                  Text(
                    isOffline ? 'Offline' : 'Available',
                    style: tt.labelMedium!.copyWith(
                      color: isOffline ? c.text3 : c.verifiedTx,
                    ),
                  ),
                  if (!isOffline && isVerified) ...[
                    Gap(AppSpacing.sm.w),
                    Text('·', style: tt.bodySmall!.copyWith(color: c.border)),
                    Gap(AppSpacing.sm.w),
                    Text(
                      '✓ Verified',
                      style: tt.labelMedium!.copyWith(color: c.verifiedTx),
                    ),
                  ],
                  if (!isOffline) ...[
                    const Spacer(),
                    // Distance is metadata, not a CTA — neutral text, not
                    // orange (MASTER §54). titleSmall + tabular figures.
                    Text(
                      '${distanceKm.toStringAsFixed(1)} km',
                      style: AppTypography.numeric(
                        tt.titleSmall!,
                      ).copyWith(fontWeight: FontWeight.w700, color: c.text2),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
