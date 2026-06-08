import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/field_label.dart';
import '../../../reviews/domain/entities/review.dart';
import '../../../reviews/presentation/providers/reviews_provider.dart';
import '../../../reviews/presentation/widgets/review_card.dart';

/// Reviews block for the profile page: an eyebrow, the most recent few
/// [ReviewCard]s, and a "SEE ALL" row into `/reviews` when there are more.
///
/// Watches [reviewsForUserProvider] (no manual load trigger). Empty behaviour
/// depends on [emptyMessage]:
///   - `null` (public / how-others-see-you view) → hides entirely when there
///     are no reviews (no placeholder, no begging copy).
///   - non-null (the owner's own profile) → shows the eyebrow + an
///     informational note (you can't add your own reviews, so it's a note, not
///     an Add CTA). The note only shows once loaded, never during loading.
class ProfileReviewsPreview extends ConsumerWidget {
  const ProfileReviewsPreview({
    super.key,
    required this.userId,
    this.emptyMessage,
  });

  final String userId;

  /// Owner-only note shown when there are no reviews. Null = hide.
  final String? emptyMessage;

  static const _previewCount = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final async = ref.watch(reviewsForUserProvider(userId));

    // Don't flash the empty note while the first fetch is still in flight.
    if (async.isLoading && !async.hasValue) return const SizedBox.shrink();

    final reviews = async.asData?.value ?? const <Review>[];

    if (reviews.isEmpty) {
      final note = emptyMessage;
      if (note == null) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('REVIEWS'),
          Gap(AppSpacing.sm.h),
          Text(note, style: tt.bodyMedium!.copyWith(color: c.text3)),
        ],
      );
    }

    final preview = reviews.take(_previewCount).toList();
    final hasMore = reviews.length > _previewCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('REVIEWS'),
        Gap(AppSpacing.sm.h),
        for (final r in preview) ReviewCard(review: r),
        if (hasMore) _SeeAllRow(count: reviews.length),
      ],
    );
  }
}

class _SeeAllRow extends StatelessWidget {
  const _SeeAllRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => context.push('/reviews'),
      borderRadius: BorderRadius.circular(AppRadius.card.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SEE ALL $count REVIEWS',
              style: tt.labelLarge!.copyWith(
                color: c.actionInk,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            Gap(4.w),
            Icon(
              AppIcons.chevronRight,
              size: AppIconSize.inline.r,
              color: c.actionInk,
            ),
          ],
        ),
      ),
    );
  }
}
