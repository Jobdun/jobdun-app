import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:lottie/lottie.dart';

import '../../../app/theme/app_colors.dart';
import '../../widgets/app_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.lottieAsset,
    required this.headline,
    this.body,
    this.ctaLabel,
    this.onCta,
  });

  final String lottieAsset;
  final String headline;
  final String? body;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(lottieAsset, width: 200.w, height: 200.h, repeat: false),
            Gap(AppSpacing.md.h),
            Text(
              headline.toUpperCase(),
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            if (body != null) ...[
              Gap(AppSpacing.sm.h),
              Text(
                body!,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: c.text2),
                textAlign: TextAlign.center,
              ),
            ],
            if (ctaLabel != null && onCta != null) ...[
              Gap(AppSpacing.lg.h),
              AppButton(label: ctaLabel!, onPressed: onCta),
            ],
          ],
        ),
      ),
    );
  }
}
