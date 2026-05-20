import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/design/colors.dart';
import '../../../auth/presentation/widgets/role_intent_cta.dart';
import '../widgets/ftue_hero_photo.dart';
import '../widgets/ftue_slide.dart';

// Slide 3 — "Built for Aussie sites." Final slide carries the two role CTAs
// (deep-link straight into the matching /register flow) and an optional
// "I already have an account · LOG IN" link. The login link is hidden when
// the user arrived via /login → Create account → so we don't bounce them
// back into a loop.
class SlideThreeAction extends StatelessWidget {
  const SlideThreeAction({
    super.key,
    required this.onHiring,
    required this.onWorking,
    this.onLoginLink,
  });

  static const heroAsset = 'assets/images/ftue/slide_3_aussie_site.jpg';

  final VoidCallback onHiring;
  final VoidCallback onWorking;

  /// null hides the bottom login link entirely. Passed null when the user
  /// reached /ftue via the Create-account link on /login.
  final VoidCallback? onLoginLink;

  @override
  Widget build(BuildContext context) {
    return FtueSlide(
      visual: const FtueHeroPhoto(
        assetPath: heroAsset,
        slideIndex: 2,
        semanticLabel: 'Australian construction site with tradies',
      ),
      headlineLine1: 'BUILT FOR',
      headlineLine2: 'AUSSIE SITES.',
      bodyLine1: 'Made in Australia. For builders,',
      bodyLine2: 'sparkies, chippies, plumbers, and crews.',
      footer: _Ctas(
        onHiring: onHiring,
        onWorking: onWorking,
        onLoginLink: onLoginLink,
      ),
    );
  }
}

class _Ctas extends StatelessWidget {
  const _Ctas({
    required this.onHiring,
    required this.onWorking,
    required this.onLoginLink,
  });

  final VoidCallback onHiring;
  final VoidCallback onWorking;
  final VoidCallback? onLoginLink;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RoleIntentCta(
          icon: Iconsax.buildings,
          label: "I'M HIRING",
          subtitle: 'Post a job. Get quotes.',
          onTap: onHiring,
        ),
        Gap(12.h),
        RoleIntentCta(
          icon: Iconsax.briefcase,
          label: "I'M LOOKING FOR WORK",
          subtitle: 'Find jobs near you.',
          onTap: onWorking,
        ),
        if (onLoginLink != null) ...[
          Gap(AppSpacing.md.h),
          Semantics(
            button: true,
            label: 'I already have an account. Log in.',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onLoginLink,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'I already have an account',
                      textAlign: TextAlign.center,
                      style: tt.bodySmall!.copyWith(color: c.text3),
                    ),
                    Gap(4.h),
                    Text(
                      'LOG IN',
                      textAlign: TextAlign.center,
                      style: tt.bodySmall!.copyWith(
                        color: c.text2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        decoration: TextDecoration.underline,
                        decorationColor: c.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
