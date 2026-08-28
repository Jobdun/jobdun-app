import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/design/colors.dart';

/// Progress bars under the onboarding headline.
///
/// Figma `JobDun-Screens` → Onboard (node 50:9946) draws three equal 32x8
/// pills rather than dots — the current page is solid safety orange, the rest
/// are the same orange at 30%. Equal widths are the point: they read as
/// "three chapters", not as a dot that grows, so the row never reflows as the
/// user swipes.
class FtuePageIndicator extends StatelessWidget {
  const FtuePageIndicator({
    super.key,
    required this.controller,
    required this.count,
  });

  final PageController controller;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bar = DotDecoration(
      width: 32.w,
      height: 8.h,
      borderRadius: BorderRadius.circular(4.r),
      color: c.action,
    );

    return SmoothPageIndicator(
      controller: controller,
      count: count,
      // Tappable, because swipe is not a universal gesture on every surface
      // this ships to — on desktop web the bars are the discoverable way to
      // move between slides.
      onDotClicked: (index) => controller.animateToPage(
        index,
        duration: AppMotion.medium,
        curve: AppMotion.standard,
      ),
      effect: CustomizableEffect(
        spacing: AppSpacing.sm.w,
        activeDotDecoration: bar,
        dotDecoration: bar.copyWith(color: c.action.withValues(alpha: 0.3)),
      ),
    );
  }
}
