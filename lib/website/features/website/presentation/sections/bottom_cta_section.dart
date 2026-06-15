import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/design/widgets/jobdun_logo.dart';

/// The final CTA. Single column, no header text, no body paragraph.
/// The brand mark + the headline + two store buttons are the whole
/// section. Minimal, declarative, in the FTUE voice.
class BottomCtaSection extends StatelessWidget {
  const BottomCtaSection({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      color: c.background,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl.w,
        vertical: AppSpacing.xxl.h * 2,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              const SizedBox(
                width: 80,
                height: 80,
                child: JobdunLogo(variant: LogoVariant.badge),
              ),
              Gap(AppSpacing.xl.h),
              Text(
                'Ready when you are.',
                textAlign: TextAlign.center,
                style: tt.displaySmall!.copyWith(
                  color: c.text1,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              Gap(AppSpacing.xl.h),
              Text(
                'iOS  ·  Android  ·  AU launch markets only',
                textAlign: TextAlign.center,
                style: tt.bodyMedium!.copyWith(
                  color: c.text2,
                  letterSpacing: 1.2,
                ),
              ),
              Gap(AppSpacing.lg.h),
              // Two text buttons — App Store / Play Store placeholders
              // until the real badge URLs are available.
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.md.w,
                runSpacing: AppSpacing.md.h,
                children: const [
                  _StoreButton(label: 'APP STORE'),
                  _StoreButton(label: 'GOOGLE PLAY'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreButton extends StatelessWidget {
  const _StoreButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: c.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadius.btn.r),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(AppRadius.btn.r),
        child: Container(
          constraints: BoxConstraints(minHeight: 56.h),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.xl.w,
            vertical: AppSpacing.md.h,
          ),
          child: Text(
            label,
            style: tt.labelLarge!.copyWith(color: c.text1),
          ),
        ),
      ),
    );
  }
}
