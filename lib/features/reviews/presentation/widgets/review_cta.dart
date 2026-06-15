import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/theme/app_icons.dart';
import '../providers/reviews_provider.dart';
import 'review_compose_sheet.dart';

/// Post-hire review entry point for an application card. Shows LEAVE-REVIEW
/// until the signed-in user has reviewed this job's other party, then a
/// read-only "you rated" row. Hidden while the lookup is in flight.
class ReviewCta extends ConsumerWidget {
  const ReviewCta({
    super.key,
    required this.jobId,
    required this.revieweeId,
    required this.revieweeName,
    required this.label,
  });

  final String jobId;
  final String revieweeId;
  final String revieweeName;

  /// e.g. 'REVIEW TRADIE' / 'REVIEW BUILDER'.
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final existing = ref.watch(myReviewForJobProvider(jobId));
    return existing.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (review) {
        if (review == null) {
          return JButton(
            label: label,
            size: JButtonSize.compact,
            icon: AppIcons.star,
            onPressed: () => showReviewComposeSheet(
              context,
              jobId: jobId,
              revieweeId: revieweeId,
              revieweeName: revieweeName,
            ),
          );
        }
        final c = context.c;
        final tt = Theme.of(context).textTheme;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RatingBarIndicator(
              rating: review.rating.toDouble(),
              itemCount: 5,
              itemSize: 16.r,
              unratedColor: c.border,
              itemBuilder: (_, _) => Icon(AppIcons.starFilled, color: c.star),
            ),
            Gap(AppSpacing.sm.w),
            Text(
              'YOU RATED ${review.rating}/5',
              style: tt.labelMedium!.copyWith(
                color: c.text2,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        );
      },
    );
  }
}
