import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/services/profile_analytics.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

// Per-session dismiss — banner hides for the rest of the run after dismiss
// and re-appears on next cold start. Riverpod-scoped so the home screen and
// any future surfaces share the same dismissed flag without prop drilling.
class _DismissedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void dismiss() => state = true;
}

final _completenessBannerDismissedProvider =
    NotifierProvider<_DismissedNotifier, bool>(_DismissedNotifier.new);

// Track which pct value we last fired profile.banner_shown for so re-renders
// (theme switches, scroll triggers) don't spam the funnel. Reset implicitly
// when the user dismisses (state goes hidden) and re-fires on next show.
class _ShownPctNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void mark(int pct) => state = pct;
}

final _bannerShownPctProvider = NotifierProvider<_ShownPctNotifier, int?>(
  _ShownPctNotifier.new,
);

class ProfileCompletenessBanner extends ConsumerWidget {
  const ProfileCompletenessBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final pct = ref.watch(
      profileControllerProvider.select((s) => s.profileCompletenessPct),
    );
    final dismissed = ref.watch(_completenessBannerDismissedProvider);

    if (pct >= 100 || dismissed) return const SizedBox.shrink();

    // Fire profile.banner_shown once per (pct, mounted) cycle. Guard against
    // build storms by only emitting when the cached value differs.
    final lastShown = ref.read(_bannerShownPctProvider);
    if (lastShown != pct) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(_bannerShownPctProvider.notifier).mark(pct);
        ProfileAnalytics.bannerShown(pct: pct);
      });
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
      child: Container(
        padding: EdgeInsets.fromLTRB(14.w, 12.h, 8.w, 12.h),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(color: c.action, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36.r,
              height: 36.r,
              decoration: BoxDecoration(
                color: c.action,
                borderRadius: BorderRadius.circular(AppRadius.avatar.r),
              ),
              child: Icon(
                AppIcons.userEdit,
                size: 18.r,
                color: Colors.white, // intentional: white-on-action
              ),
            ),
            Gap(12.w),
            Expanded(
              // Tap target on the body of the banner — opens /profile/edit and
              // counts as the primary CTA in analytics. Dismiss is the only
              // alternative path and is handled separately on the right.
              child: Semantics(
                button: true,
                label: 'Complete your profile. $pct percent done.',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    ProfileAnalytics.bannerCtaTapped();
                    // go() (not push) so GoRouter switches the StatefulShell
                    // to the Profile branch — otherwise currentIndex stays on
                    // Home and the bottom-nav Profile icon never activates
                    // while a profile screen is on screen.
                    context.go('/profile/edit');
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COMPLETE YOUR PROFILE',
                        style: tt.labelSmall!.copyWith(
                          letterSpacing: 0.12 * 11,
                          color: c.text1,
                        ),
                      ),
                      Gap(4.h),
                      Row(
                        children: [
                          Expanded(
                            child: LinearPercentIndicator(
                              percent: (pct / 100).clamp(0.0, 1.0),
                              lineHeight: 4.h,
                              backgroundColor: c.border,
                              progressColor: c.action,
                              barRadius: Radius.circular(2.r),
                              padding: EdgeInsets.zero,
                              animation: true,
                              animateFromLastPercent: true,
                              animationDuration: 600,
                            ),
                          ),
                          Gap(8.w),
                          Text(
                            '$pct%',
                            style: tt.labelSmall!.copyWith(
                              color: c.action,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                ProfileAnalytics.bannerDismissed();
                ref
                    .read(_completenessBannerDismissedProvider.notifier)
                    .dismiss();
              },
              icon: Icon(AppIcons.closeBox, size: 18.r, color: c.text3),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: 32.r, minHeight: 32.r),
              tooltip: 'Dismiss',
            ),
          ],
        ),
      ),
    );
  }
}
