import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import 'ftue_role_row.dart';

/// The decision block pinned under the onboarding carousel.
///
/// Figma `JobDun-Screens` → Onboard (node 30:8138) repeats this identically on
/// all three slides, so it lives outside the [PageView] and never moves while
/// the hero swipes. That repetition is deliberate — it means the user can act
/// from slide 1 without sitting through the story, which is why the old SKIP
/// affordance is gone: both roles, the log-in link and guest browsing are on
/// screen at all times.
class FtueRoleSheet extends StatelessWidget {
  const FtueRoleSheet({
    super.key,
    required this.onFindWork,
    required this.onHireWorkers,
    required this.onLogin,
    required this.onBrowse,
  });

  /// Trade side of the marketplace — deep-links to `/register?role=trade`.
  final VoidCallback onFindWork;

  /// Builder side — deep-links to `/register?role=builder`.
  final VoidCallback onHireWorkers;

  final VoidCallback onLogin;

  /// Guest browsing (App Review 5.1.1(v)) — nobody has to register to look.
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md.w,
        AppSpacing.md.h,
        AppSpacing.md.w,
        AppSpacing.lg.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: c.surface,
            clipBehavior: Clip.antiAlias,
            // `shape` carries both the radius and the border — Material
            // asserts if `borderRadius` is passed alongside it.
            shape: RoundedRectangleBorder(
              side: BorderSide(color: c.borderStrong),
              borderRadius: BorderRadius.circular(AppRadius.overlayCard.r),
            ),
            // Figma Elevation/xs. A literal black on purpose — it resolves to
            // invisible on dark, where the border does the separating.
            shadowColor: Colors.black.withValues(alpha: 0.1),
            elevation: 4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FtueRoleRow.accent(
                  key: const Key('ftue.role.trade'),
                  icon: AppIcons.briefcaseFilled,
                  title: 'Find Work',
                  subtitle: 'Discover jobs near you',
                  onTap: onFindWork,
                  showDivider: true,
                ),
                FtueRoleRow.inverse(
                  key: const Key('ftue.role.builder'),
                  icon: AppIcons.peopleGroupFilled,
                  title: 'Hire Workers',
                  subtitle: 'Post a job. Get quotes.',
                  onTap: onHireWorkers,
                ),
              ],
            ),
          ),
          Gap(AppSpacing.lg.h),
          Semantics(
            button: true,
            label: 'I already have an account. Log in.',
            child: GestureDetector(
              key: const Key('ftue.login'),
              behavior: HitTestBehavior.opaque,
              onTap: onLogin,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
                child: Text.rich(
                  TextSpan(
                    style: tt.bodyMedium!.copyWith(color: c.text1, height: 1.2),
                    children: [
                      const TextSpan(text: 'I already have an account. '),
                      TextSpan(
                        text: 'LOGIN',
                        style: tt.bodyMedium!.copyWith(
                          color: c.actionInk,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          decoration: TextDecoration.underline,
                          decorationColor: c.actionInk,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Gap(AppSpacing.md.h),
          Semantics(
            button: true,
            label: 'Browse open jobs without an account.',
            child: GestureDetector(
              key: const Key('ftue.browse'),
              behavior: HitTestBehavior.opaque,
              onTap: onBrowse,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
                child: Text(
                  'Browse open jobs',
                  textAlign: TextAlign.center,
                  style: tt.titleMedium!.copyWith(
                    color: c.actionInk,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
