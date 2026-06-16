import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/theme/app_icons.dart';
import '../widgets/phone_frame.dart';

/// Section-level page padding. Every section uses this so the page
/// has consistent horizontal breathing room — the design system
/// page margin scales with viewport width.
class _PagePad extends StatelessWidget {
  const _PagePad({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final pad = w >= 1100
        ? 96.0
        : w >= 720
        ? 64.0
        : 24.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: pad),
      child: child,
    );
  }
}

/// Hero — a 2-column split, text on the left, the real app on the right.
/// No eyebrow. No "tiny text → huge text" formula. The screen itself
/// is the hero.
///
/// On mobile the columns stack and the phone drops below the copy.
class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final w = MediaQuery.sizeOf(context).width;
    final stacked = w < 960;

    return Container(
      width: double.infinity,
      color: c.background,
      // Extra top room clears the floating glass nav; generous bottom rhythm
      // hands off to the trust band below.
      padding: EdgeInsets.only(
        top: (AppSpacing.xxl * 2.2).h,
        bottom: AppSpacing.xxl.h * 1.5,
      ),
      child: _PagePad(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const _HeroPhone(width: 280),
                      Gap(AppSpacing.xxl.h),
                      _CopyBlock(
                        tt: tt,
                        c: c,
                        onHire: () => context.go('/for-builders'),
                        onCrew: () => context.go('/for-crews'),
                        align: TextAlign.center,
                      ),
                    ],
                  )
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _CopyBlock(
                            tt: tt,
                            c: c,
                            onHire: () => context.go('/for-builders'),
                            onCrew: () => context.go('/for-crews'),
                          ),
                        ),
                        Gap(64.w),
                        const Expanded(
                          flex: 5,
                          child: Center(child: _HeroPhone(width: 320)),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _CopyBlock extends StatelessWidget {
  const _CopyBlock({
    required this.tt,
    required this.c,
    required this.onHire,
    required this.onCrew,
    this.align = TextAlign.left,
  });

  final TextTheme tt;
  final JColors c;
  final VoidCallback onHire;
  final VoidCallback onCrew;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // No logo here — the sticky SiteTopBar already carries the
        // wordmark. Rendering it twice in the same viewport made
        // the brand mark look like a repeating watermark.
        Semantics(
          header: true,
          child: Text(
            'Hire the right\ntradie in minutes.',
            textAlign: align,
            style: tt.displayLarge!.copyWith(
              color: c.text1,
              height: 1.05,
              letterSpacing: -0.5,
            ),
            maxLines: 3,
          ),
        ),
        Gap(AppSpacing.lg.h),
        Text(
          'Post the job. Get verified applicants. Hire the one you want. '
          'Every trade licence-checked. Every builder verified. '
          'No agencies, no timewasters.',
          textAlign: align,
          style: tt.bodyLarge!.copyWith(color: c.text2, height: 1.55),
        ),
        Gap(AppSpacing.xl.h),
        Wrap(
          spacing: AppSpacing.md.w,
          runSpacing: AppSpacing.md.h,
          alignment: align == TextAlign.center
              ? WrapAlignment.center
              : WrapAlignment.start,
          children: [
            _Cta(label: "I'M HIRING", primary: true, onPressed: onHire),
            _Cta(
              label: "I'M LOOKING FOR WORK",
              primary: false,
              onPressed: onCrew,
            ),
          ],
        ),
      ],
    );
  }
}

/// The hero phone with the one sanctioned soft orange radial glow behind it.
/// The glow is the single piece of "depth" the refined-flat+ direction allows
/// on the marketing site — a quiet brand halo, not a drop shadow.
class _HeroPhone extends StatelessWidget {
  const _HeroPhone({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.72,
                  colors: [
                    c.action.withValues(alpha: 0.22),
                    c.action.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),
        PhoneFrame(
          asset: 'assets/website/screenshots/hire-celebration.png',
          tilt: -0.04,
          width: width,
          semanticLabel:
              'The Jobdun app showing the hire confirmation: a green checkmark, "YOU\'RE CONNECTED" and "You hired Ken."',
        ),
      ],
    );
  }
}

class _Cta extends StatelessWidget {
  const _Cta({
    required this.label,
    required this.primary,
    required this.onPressed,
  });

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
              Icon(
                AppIcons.chevronRight,
                size: AppIconSize.inline.r,
                color: fg,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
