import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';

/// "1 review" / "24 reviews" — the count that turns a bare score into social
/// proof (S11). The credibility multiplier is the volume, not the digit.
String reviewCountLabel(int count) =>
    count == 1 ? '1 review' : '$count reviews';

/// Star bar + numeric average + review count. Hidden entirely when [count] is
/// 0 — a brand-new tradie shows no rating chrome rather than a hollow "0.0".
class ProfileRatingBlock extends StatelessWidget {
  const ProfileRatingBlock({
    super.key,
    required this.average,
    required this.count,
  });

  final double? average;
  final int count;

  @override
  Widget build(BuildContext context) {
    final avg = average;
    if (count <= 0 || avg == null) return const SizedBox.shrink();
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        RatingBarIndicator(
          rating: avg,
          itemCount: 5,
          itemSize: 16.r,
          unratedColor: c.border,
          itemBuilder: (_, _) => Icon(AppIcons.starFilled, color: c.star),
        ),
        Gap(8.w),
        Text(
          avg.toStringAsFixed(1),
          style: tt.titleMedium!.copyWith(
            fontWeight: FontWeight.w700,
            color: c.text1,
          ),
        ),
        Gap(6.w),
        Text(
          '(${reviewCountLabel(count)})',
          style: tt.bodySmall!.copyWith(color: c.text2),
        ),
      ],
    );
  }
}
