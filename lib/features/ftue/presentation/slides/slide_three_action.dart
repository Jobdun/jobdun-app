import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/widgets/social_auth_button.dart';
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
    this.onContinueWithGoogle,
    this.onLoginLink,
    this.onBrowse,
  });

  static const heroAsset = 'assets/images/ftue/slide_3_aussie_site.jpg';

  final VoidCallback onHiring;
  final VoidCallback onWorking;

  /// Optional Google SSO shortcut — when non-null, renders a small icon-tile
  /// between the role CTAs and the login link so users can jump straight to
  /// Google without the email signup form. The OnboardingCompletionSheet on
  /// /home handles role + name capture after SSO.
  final VoidCallback? onContinueWithGoogle;

  /// null hides the bottom login link entirely. Passed null when the user
  /// reached /ftue via the Create-account link on /login.
  final VoidCallback? onLoginLink;

  /// Guest browsing entry (App Review 5.1.1(v)) — when non-null, renders a
  /// "browse open jobs" link so nobody has to register just to look.
  final VoidCallback? onBrowse;

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
        onContinueWithGoogle: onContinueWithGoogle,
        onLoginLink: onLoginLink,
        onBrowse: onBrowse,
      ),
    );
  }
}

class _Ctas extends StatelessWidget {
  const _Ctas({
    required this.onHiring,
    required this.onWorking,
    required this.onContinueWithGoogle,
    required this.onLoginLink,
    required this.onBrowse,
  });

  final VoidCallback onHiring;
  final VoidCallback onWorking;
  final VoidCallback? onContinueWithGoogle;
  final VoidCallback? onLoginLink;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RoleIntentCta(
          icon: AppIcons.builder,
          label: "I'M HIRING",
          subtitle: 'Post a job. Get quotes.',
          onTap: onHiring,
        ),
        Gap(12.h),
        RoleIntentCta(
          icon: AppIcons.briefcase,
          label: "I'M LOOKING FOR WORK",
          subtitle: 'Find jobs near you.',
          onTap: onWorking,
        ),
        if (onContinueWithGoogle != null) ...[
          Gap(AppSpacing.md.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'or sign up faster with',
                style: tt.bodySmall!.copyWith(color: c.text3),
              ),
              Gap(10.w),
              SocialAuthButton.google(
                key: const Key('ftue.sso.google'),
                onTap: onContinueWithGoogle!,
                isLoading: false,
              ),
            ],
          ),
        ],
        if (onBrowse != null) ...[
          Gap(AppSpacing.md.h),
          Semantics(
            button: true,
            label: 'Browse open jobs without an account.',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBrowse,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: tt.bodySmall!.copyWith(color: c.text3),
                    children: [
                      const TextSpan(text: 'Just looking?  '),
                      TextSpan(
                        text: 'BROWSE OPEN JOBS',
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
          ),
        ],
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
