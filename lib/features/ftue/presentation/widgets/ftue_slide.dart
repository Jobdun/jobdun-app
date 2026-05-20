import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../app/theme/app_theme.dart';

// Single-slide template for the FTUE carousel. Photo (or custom visual) at
// the top, two-line Oswald headline below, two-line body paragraph under
// that, optional footer (slide 3's CTA stack). The `visual` slot is
// optional so a slide can be text-only when its own elements (e.g. slide
// 2's map-pin chip row) carry the visual weight.
class FtueSlide extends StatelessWidget {
  const FtueSlide({
    super.key,
    required this.headlineLine1,
    required this.headlineLine2,
    required this.bodyLine1,
    required this.bodyLine2,
    this.visual,
    this.footer,
  });

  final String headlineLine1;
  final String headlineLine2;
  final String bodyLine1;
  final String bodyLine2;

  /// Hero photo / custom Flutter widget rendered above the headline. Null =
  /// no visual block (slide 2 owns its own pin chips below the copy).
  final Widget? visual;

  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Gap(AppSpacing.lg.h),
          if (visual != null) ...[visual!, Gap(AppSpacing.lg.h)],
          Text(
            headlineLine1,
            style: AppTheme.brandDisplay(
              c.text1,
            ).copyWith(fontSize: 32.sp, height: 1.05, letterSpacing: 2.0),
          ),
          Text(
            headlineLine2,
            style: AppTheme.brandDisplay(
              c.action,
            ).copyWith(fontSize: 32.sp, height: 1.05, letterSpacing: 2.0),
          ),
          Gap(AppSpacing.md.h),
          Text(
            bodyLine1,
            style: tt.bodyMedium!.copyWith(
              color: c.text2,
              height: 1.45,
              fontSize: 14.sp,
            ),
          ),
          Text(
            bodyLine2,
            style: tt.bodyMedium!.copyWith(
              color: c.text2,
              height: 1.45,
              fontSize: 14.sp,
            ),
          ),
          if (footer != null) ...[Gap(AppSpacing.lg.h), footer!],
          Gap(AppSpacing.lg.h),
        ],
      ),
    );
  }
}
