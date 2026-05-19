import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../app/theme/app_colors.dart';

// Three-dot indicator for the FTUE carousel. Active dot uses safety orange
// per design-system/jobdun/pages/auth-onboarding.md.
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
    return SmoothPageIndicator(
      controller: controller,
      count: count,
      effect: ExpandingDotsEffect(
        dotHeight: 6.h,
        dotWidth: 6.w,
        expansionFactor: 4,
        spacing: 6.w,
        activeDotColor: c.action,
        dotColor: c.border,
      ),
    );
  }
}
