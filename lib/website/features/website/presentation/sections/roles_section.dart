import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../widgets/phone_frame.dart';

/// Two side-by-side phones, one per role. No "BUILDER / TRADE" eyebrow,
/// no paragraph, no "POST A JOB" CTA on the card — the role is
/// conveyed by the copy line + the screen below. CTAs live in the
/// bottom-CTA section.
class RolesSection extends StatelessWidget {
  const RolesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = MediaQuery.sizeOf(context).width;
    final stacked = w < 960;

    final builder = const _RoleBlock(
      asset: 'assets/website/screenshots/create-account.png',
      caption: 'For builders hiring trades.',
      tilt: -0.03,
    );
    final crew = const _RoleBlock(
      asset: 'assets/website/screenshots/ftue-splash.png',
      caption: 'For crews looking for work.',
      tilt: 0.04,
    );

    return Container(
      width: double.infinity,
      color: c.surface, // alternating section bg — visual rhythm
      padding: EdgeInsets.symmetric(
        horizontal: _hPad(w),
        vertical: AppSpacing.xxl.h * 1.5,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: stacked
              ? Column(children: [builder, Gap(AppSpacing.xxl.h), crew])
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: builder),
                      Gap(AppSpacing.xxl.w),
                      Expanded(child: crew),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  double _hPad(double w) {
    if (w >= 1100) return AppSpacing.xxl.w;
    if (w >= 720) return AppSpacing.xl.w;
    return AppSpacing.lg.w;
  }
}

class _RoleBlock extends StatelessWidget {
  const _RoleBlock({required this.asset, required this.caption, required this.tilt});

  final String asset;
  final String caption;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: PhoneFrame(asset: asset, tilt: tilt, maxHeight: 560),
        ),
        Gap(AppSpacing.lg.h),
        Text(
          caption,
          style: tt.headlineSmall!.copyWith(
            color: c.text1,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
