import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/theme/app_icons.dart';
import '../../domain/entities/review.dart';
import '../providers/reviews_provider.dart';

/// Opens the review compose sheet for a hired job. Resolves true when a
/// review was submitted.
Future<bool?> showReviewComposeSheet(
  BuildContext context, {
  required String jobId,
  required String revieweeId,
  required String revieweeName,
}) => showJSheet<bool>(
  context: context,
  builder: (_) => ReviewComposeSheet(
    jobId: jobId,
    revieweeId: revieweeId,
    revieweeName: revieweeName,
  ),
);

/// Star rating + optional comment for the other party on a hired job.
/// One review per reviewer per job (DB unique constraint); the caller hides
/// the entry point once `myReviewForJobProvider` returns a row.
class ReviewComposeSheet extends ConsumerStatefulWidget {
  const ReviewComposeSheet({
    super.key,
    required this.jobId,
    required this.revieweeId,
    required this.revieweeName,
  });

  final String jobId;
  final String revieweeId;
  final String revieweeName;

  @override
  ConsumerState<ReviewComposeSheet> createState() => _ReviewComposeSheetState();
}

class _ReviewComposeSheetState extends ConsumerState<ReviewComposeSheet> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reviewerId = ref.read(currentUserIdSyncProvider);
    if (reviewerId == null || _rating < 1) return;
    setState(() => _submitting = true);

    final comment = _comment.text.trim();
    final ok = await ref
        .read(reviewsControllerProvider.notifier)
        .submit(
          Review(
            id: '',
            jobId: widget.jobId,
            reviewerId: reviewerId,
            revieweeId: widget.revieweeId,
            rating: _rating,
            comment: comment.isEmpty ? null : comment,
            createdAt: DateTime.now(),
          ),
        );

    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      HapticFeedback.lightImpact();
      ref.invalidate(myReviewForJobProvider(widget.jobId));
      Navigator.pop(context, true);
    } else {
      final error = ref.read(reviewsControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Review failed — try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl.w,
        AppSpacing.lg.h,
        AppSpacing.xl.w,
        AppSpacing.xl.h + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RATE ${widget.revieweeName.toUpperCase()}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tt.headlineSmall!.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w700,
            ),
          ),
          Gap(AppSpacing.sm.h),
          Text(
            'How did this job go? Your review is public on their profile.',
            style: tt.bodyMedium!.copyWith(color: c.text2),
          ),
          Gap(AppSpacing.xl.h),
          Center(
            child: RatingBar.builder(
              initialRating: 0,
              minRating: 1,
              itemCount: 5,
              itemSize: 44.r,
              glow: false,
              unratedColor: c.border,
              itemPadding: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w),
              itemBuilder: (_, _) => Icon(AppIcons.starFilled, color: c.star),
              onRatingUpdate: (value) {
                HapticFeedback.selectionClick();
                setState(() => _rating = value.round());
              },
            ),
          ),
          Gap(AppSpacing.xl.h),
          TextField(
            controller: _comment,
            maxLines: 4,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            style: tt.bodyLarge!.copyWith(color: c.text1),
            decoration: const InputDecoration(
              hintText: 'What should other users know? (optional)',
            ),
          ),
          Gap(AppSpacing.lg.h),
          JButton(
            label: 'SUBMIT REVIEW',
            isLoading: _submitting,
            onPressed: _rating >= 1 && !_submitting ? _submit : null,
          ),
        ],
      ),
    );
  }
}
