import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';

// Single-slide template for the FTUE carousel. Visual sits at the top, then a
// two-line Oswald headline, then a single body paragraph, then an optional
// footer (the slide-3 CTA stack). Visual slot is intentionally a Widget so
// the next sprint can drop a Lottie in without touching this layout.
class FtueSlide extends StatelessWidget {
  const FtueSlide({
    super.key,
    required this.headlineLine1,
    required this.headlineLine2,
    required this.body,
    required this.visual,
    this.footer,
  });

  final String headlineLine1;
  final String headlineLine2;
  final String body;
  final Widget visual;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Gap(AppSpacing.xxl.h),
          // Visual area — sized generously so static icons + future Lotties
          // both feel anchored. Bounded so the headline never gets pushed
          // off a 360×640 viewport. Container (not SizedBox) keeps the
          // design-system lint happy — Gap is reserved for spacing.
          Container(
            height: 180.h,
            child: Center(child: visual),
          ),
          Gap(AppSpacing.xl.h),
          Text(
            headlineLine1,
            style: AppTheme.brandDisplay(
              c.text1,
            ).copyWith(fontSize: 38.sp, height: 1.05, letterSpacing: 2.0),
          ),
          Text(
            headlineLine2,
            style: AppTheme.brandDisplay(
              c.action,
            ).copyWith(fontSize: 38.sp, height: 1.05, letterSpacing: 2.0),
          ),
          Gap(AppSpacing.md.h),
          Text(
            body,
            style: tt.bodyMedium!.copyWith(
              color: c.text2,
              height: 1.45,
              fontSize: 14.sp,
            ),
          ),
          if (footer != null) ...[Gap(AppSpacing.lg.h), footer!],
          // Spacer pushes content up so the page indicator at the parent's
          // bottom edge stays glued to the bottom; without it the body
          // crowds the dots on tall screens.
          const Spacer(),
        ],
      ),
    );
  }
}
