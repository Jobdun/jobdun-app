import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/design/widgets/jobdun_logo.dart';
import '../../../../../core/theme/app_icons.dart';
import '../providers/active_section_provider.dart';
import '../widgets/phone_frame.dart';

/// Hero — a 2-column split, text on the left, the real app on the right.
/// No eyebrow. No "tiny text → huge text" formula. The screen itself
/// is the hero.
///
/// On mobile the columns stack and the phone drops below the copy.
class HeroSection extends ConsumerWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final w = MediaQuery.sizeOf(context).width;
    final stacked = w < 960;

    return Container(
      width: double.infinity,
      color: c.background,
      padding: EdgeInsets.symmetric(
        horizontal: _hPad(w),
        vertical: AppSpacing.xxl.h * 1.5,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CopyBlock(tt: tt, c: c, onHire: () => _scrollTo(ref, 'hiring'), onCrew: () => _scrollTo(ref, 'crews')),
                    Gap(AppSpacing.xxl.h),
                    const Center(child: PhoneFrame(asset: 'assets/website/screenshots/ftue-splash.png', tilt: -0.04)),
                  ],
                )
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _CopyBlock(tt: tt, c: c, onHire: () => _scrollTo(ref, 'hiring'), onCrew: () => _scrollTo(ref, 'crews')),
                      ),
                      Gap(AppSpacing.xxl.w),
                      Expanded(
                        flex: 5,
                        child: Center(
                          child: PhoneFrame(
                            asset: 'assets/website/screenshots/ftue-splash.png',
                            tilt: -0.04,
                            maxHeight: 640.h,
                          ),
                        ),
                      ),
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

  void _scrollTo(WidgetRef ref, String id) {
    ref.read(scrollToProvider.notifier).request(id);
  }
}

class _CopyBlock extends StatelessWidget {
  const _CopyBlock({
    required this.tt,
    required this.c,
    required this.onHire,
    required this.onCrew,
  });

  final TextTheme tt;
  final JColors c;
  final VoidCallback onHire;
  final VoidCallback onCrew;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo wordmark up top — small, sets brand context
        const JobdunLogo(variant: LogoVariant.full),
        Gap(AppSpacing.xl.h),
        Text(
          'Only verified.\nNo timewasters.',
          style: tt.displayLarge!.copyWith(
            color: c.text1,
            height: 1.05,
            letterSpacing: -0.5,
          ),
          maxLines: 3,
        ),
        Gap(AppSpacing.lg.h),
        Text(
          'Every trade licence-checked. Every builder verified. '
          'Built for the people who actually build Australia.',
          style: tt.bodyLarge!.copyWith(color: c.text2, height: 1.55),
        ),
        Gap(AppSpacing.xl.h),
        Wrap(
          spacing: AppSpacing.md.w,
          runSpacing: AppSpacing.md.h,
          children: [
            _Cta(label: "I'M HIRING", primary: true, onPressed: onHire),
            _Cta(label: "I'M LOOKING FOR WORK", primary: false, onPressed: onCrew),
          ],
        ),
      ],
    );
  }
}

class _Cta extends StatelessWidget {
  const _Cta({required this.label, required this.primary, required this.onPressed});

  final String label;
  final bool primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final bg = primary ? c.action : c.surfaceRaised;
    final fg = primary ? c.onAction : c.text1;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.btn.r),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.btn.r),
        child: Container(
          constraints: BoxConstraints(minHeight: 56.h),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg.w,
            vertical: AppSpacing.md.h,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: tt.labelLarge!.copyWith(color: fg)),
              Gap(AppSpacing.sm.w),
              Icon(AppIcons.chevronRight, size: AppIconSize.inline.r, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
