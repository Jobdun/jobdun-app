import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:jobdun/app/theme/app_icon_size.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../domain/entities/review.dart';

/// Single review row. Surfaces:
///   - star rating + comment + reviewer + date
///   - v2 hire-time verification snapshot as a subtitle below the comment
///     ("Was verified at the time of hire (ABN + NSW Electrical Licence)"
///      / "Was not verified at the time of hire").
///
/// When `verificationSnapshot` is null (legacy reviews from before v2 / a
/// trade reviewing a builder where no snapshot was stamped), the subtitle
/// is omitted — never invented.
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Stars(rating: review.rating),
          Gap(8.h),
          if (review.comment?.isNotEmpty == true) ...[
            Text(
              review.comment!,
              style: TextStyle(fontSize: 14.sp, color: c.text1, height: 1.45),
            ),
            Gap(8.h),
          ],
          Text(
            DateFormat('d MMM yyyy').format(review.createdAt),
            style: TextStyle(fontSize: 11.sp, color: c.text3),
          ),
          if (review.verificationSnapshot != null) ...[
            Gap(8.h),
            _SnapshotSubtitle(snapshot: review.verificationSnapshot!),
          ],
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: List.generate(5, (i) {
        final filled = i < rating;
        return Padding(
          padding: EdgeInsets.only(right: 2.w),
          child: Icon(
            AppIcons.star,
            size: AppIconSize.inline.r,
            color: filled ? c.star : c.text3,
          ),
        );
      }),
    );
  }
}

class _SnapshotSubtitle extends StatelessWidget {
  const _SnapshotSubtitle({required this.snapshot});
  final VerificationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final positive = snapshot.hadAny;
    return Row(
      children: [
        Icon(
          positive ? AppIcons.verified : AppIcons.closeCircle,
          size: AppIconSize.micro.r,
          color: positive ? c.verified : c.text3,
        ),
        Gap(6.w),
        Expanded(
          child: Text(
            _copy(),
            style: TextStyle(
              fontSize: 11.sp,
              color: positive ? c.verifiedTx : c.text3,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  String _copy() {
    if (!snapshot.hadAny) return 'Was not verified at the time of hire.';
    final parts = <String>[];
    if (snapshot.hadAbn) parts.add('ABN');
    if (snapshot.hadLicence) {
      final state = snapshot.licenceState;
      parts.add(state != null ? '$state licence' : 'licence');
    }
    return 'Was verified at the time of hire (${parts.join(' + ')}).';
  }
}
