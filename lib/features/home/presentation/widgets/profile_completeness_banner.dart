import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/services/profile_analytics.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../verification/presentation/providers/verifications_provider.dart';

// Per-session dismiss — banner hides for the rest of the run after dismiss
// and re-appears on next cold start. Riverpod-scoped so the home screen and
// any future surfaces share the same dismissed flag without prop drilling.
class _DismissedNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Reset the dismissal on account switch so a new sign-in sees their own
    // banner (it otherwise carried over the previous user's dismissed state).
    ref.listen(currentUserIdProvider, (previous, next) {
      if (previous?.value != null && previous?.value != next.value) {
        state = false;
      }
    });
    return false;
  }

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
  const ProfileCompletenessBanner({super.key, this.messageOverride});

  /// Replaces the generic body line. The profile page passes the single
  /// highest-impact gap ("Add your ABN so builders trust you") because it can
  /// compute one; home cannot, so it keeps the generic copy.
  final String? messageOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    // Wizard/regulator licence lives in public.verifications, which the
    // profile state can't see (K9) — OR it into the score.
    final wizardLicence = ref.watch(myWizardLicenceVerifiedProvider) ?? false;
    final snap = ref.watch(
      profileControllerProvider.select(
        (s) => (
          pct: s.completenessPct(hasVerifiedLicence: wizardLicence),
          isLoading: s.isLoading,
          hasProfile: s.profile != null,
          error: s.error,
        ),
      ),
    );
    final dismissed = ref.watch(_completenessBannerDismissedProvider);

    // Loading and failed loads are UNKNOWN — rendering them as "0%" (and
    // firing a false banner_shown event) told complete users their profile
    // was empty (K9, 2026-08-18 audit).
    if (snap.isLoading || snap.error != null || !snap.hasProfile) {
      return const SizedBox.shrink();
    }
    final pct = snap.pct;
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

    // Figma "Quote" card (Homepage section, node 80:4251): tinted brand fill,
    // orange hairline, title row with a close affordance, body line, then a
    // full-width 8dp progress bar. The old banner was an icon-tile + inline
    // bar at 4dp; the mock gives the bar the full width and drops the tile.
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: c.actionBg,
          borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
          border: Border.all(color: c.action),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  // Tap target on the copy — opens /profile/edit and counts as
                  // the primary CTA in analytics. Dismiss is a SIBLING, not a
                  // descendant: nesting it inside this `excludeSemantics`
                  // subtree hid the close affordance from screen readers.
                  child: Semantics(
                    button: true,
                    label: 'Complete your profile. $pct percent done.',
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        ProfileAnalytics.bannerCtaTapped();
                        // go() (not push) so GoRouter switches the
                        // StatefulShell to the Profile branch — otherwise
                        // currentIndex stays on Home and the bottom-nav
                        // Profile icon never activates while a profile screen
                        // is on screen.
                        context.go('/profile/edit');
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Complete your profile',
                            style: tt.titleMedium!.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                              color: c.text1,
                            ),
                          ),
                          Gap(4.h),
                          Text(
                            messageOverride ??
                                'Add a few details to build trust and get '
                                    'applicants',
                            style: tt.bodyMedium!.copyWith(
                              height: 1.4,
                              color: c.text1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Gap(4.w),
                _DismissButton(
                  onDismiss: () {
                    ProfileAnalytics.bannerDismissed();
                    ref
                        .read(_completenessBannerDismissedProvider.notifier)
                        .dismiss();
                  },
                ),
              ],
            ),
            Gap(12.h),
            Semantics(
              label: '$pct percent complete',
              child: LinearPercentIndicator(
                percent: (pct / 100).clamp(0.0, 1.0),
                lineHeight: 8.h,
                // The mock's brand/200 track. `actionBg` is the card's own
                // fill, so the bar would vanish into it — this is the one
                // place the tint has to sit a step darker than the ground.
                backgroundColor: c.actionTx.withValues(alpha: 0.24),
                progressColor: c.action,
                barRadius: Radius.circular(4.r),
                padding: EdgeInsets.zero,
                animation: true,
                animateFromLastPercent: true,
                animationDuration: 600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Close glyph on the completion card. Paints at the mock's 16dp but claims a
/// 44dp hit box, so dismiss stays reachable without inflating the card.
class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      label: 'Dismiss',
      child: InkResponse(
        onTap: onDismiss,
        radius: 22.r,
        child: SizedBox(
          width: 44.r,
          height: 24.r,
          child: Align(
            alignment: Alignment.topRight,
            child: Icon(AppIcons.close, size: 16.r, color: c.text1),
          ),
        ),
      ),
    );
  }
}
