import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/animated_empty_glyph.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../domain/entities/review.dart';
import '../providers/reviews_provider.dart';
import '../widgets/review_card.dart';

/// Reviews list for the current user (reviews ABOUT them).
/// v2 surface: each review carries a hire-time verification snapshot
/// (rendered as a small subtitle on each card via [ReviewCard]).
class ReviewsPage extends ConsumerStatefulWidget {
  const ReviewsPage({super.key});

  @override
  ConsumerState<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends ConsumerState<ReviewsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reload();
    });
  }

  void _reload() {
    final userId = ref.read(currentUserIdSyncProvider);
    if (userId == null) return;
    ref.read(reviewsControllerProvider.notifier).loadFor(userId);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final state = ref.watch(reviewsControllerProvider);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Reviews')),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: state.isLoading && state.reviews.isEmpty
              ? JSkeletonList(
                  enabled: true,
                  child: ListView(
                    children: List.generate(
                      4,
                      (_) => ReviewCard(review: _placeholderReview()),
                    ),
                  ),
                )
              // P6, 2026-08-18 audit: a failed load must render as an error
              // with a retry, never as the "No reviews yet" empty state.
              : state.error != null && state.reviews.isEmpty
              ? _ReviewsError(onRetry: _reload)
              : state.reviews.isEmpty
              ? _Empty()
              : ListView.builder(
                  itemCount: state.reviews.length,
                  itemBuilder: (_, i) => ReviewCard(review: state.reviews[i]),
                ),
        ),
      ),
    );
  }
}

Review _placeholderReview() => Review(
  id: 'placeholder',
  jobId: 'j',
  reviewerId: 'r',
  revieweeId: 'u',
  rating: 5,
  createdAt: DateTime.now(),
  comment: 'Loading review content placeholder.',
);

// Full-page error + RETRY (P6, 2026-08-18 audit). Mirrors the jobs feed
// `_PageError` pattern (jobs_page_widgets.dart).
class _ReviewsError extends StatelessWidget {
  const _ReviewsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.warning,
              size: AppIconSize.feature.r,
              color: c.urgent,
            ),
            Gap(AppSpacing.md.h),
            Text(
              "Couldn't load your reviews.",
              style: tt.bodyMedium!.copyWith(color: c.urgentTx),
              textAlign: TextAlign.center,
            ),
            Gap(AppSpacing.md.h),
            SizedBox(
              width: 160.w,
              child: JButton(
                label: 'RETRY',
                variant: JButtonVariant.secondary,
                onPressed: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedEmptyGlyph(
            icon: AppIcons.star,
            motion: EmptyGlyphMotion.twinkle,
            size: AppIconSize.hero.r,
          ),
          Gap(AppSpacing.md.h),
          Text(
            'No reviews yet',
            style: tt.titleLarge!.copyWith(fontWeight: FontWeight.w700),
          ),
          Gap(6.h),
          Text(
            'Reviews from completed jobs will appear here.',
            style: tt.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
