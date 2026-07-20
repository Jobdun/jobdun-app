import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/design/colors.dart';

/// Dot progress indicator for [OnboardingCompletionSheet]. The active
/// dot widens to a pill; the rest stay small. Extracted from the sheet to keep
/// that file under the size budget. [total] tracks the sheet's dynamic step
/// plan — SSO users may see fewer than three steps.
class OnboardingProgressRow extends StatelessWidget {
  const OnboardingProgressRow({super.key, required this.step, this.total = 3});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == step;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: active ? 24.w : 8.w,
            height: 8.h,
            decoration: BoxDecoration(
              color: active ? c.action : c.border,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
        );
      }),
    );
  }
}
