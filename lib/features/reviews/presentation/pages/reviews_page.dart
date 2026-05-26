import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/app_colors.dart';
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
      final userId = ref.read(currentUserIdSyncProvider);
      if (userId == null) return;
      ref.read(reviewsControllerProvider.notifier).loadFor(userId);
    });
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

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No reviews yet',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: c.text1,
            ),
          ),
          Gap(6.h),
          Text(
            'Reviews from completed jobs will appear here.',
            style: TextStyle(fontSize: 13.sp, color: c.text2),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
