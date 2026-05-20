import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/theme/app_icon_theme.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final _connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  final initial = await connectivity.checkConnectivity();
  yield _isOnline(initial);
  yield* connectivity.onConnectivityChanged.map(_isOnline);
});

bool _isOnline(List<ConnectivityResult> results) =>
    results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);

class HomeShellPage extends ConsumerWidget {
  const HomeShellPage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  // Fling threshold above which a horizontal drag counts as a tab-switch
  // gesture. ~300 px/s is the conventional Flutter "swipe" floor — slow
  // drags don't accidentally move tabs.
  static const double _swipeVelocityThreshold = 300.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineAsync = ref.watch(_connectivityProvider);
    final isOnline = onlineAsync.asData?.value ?? true;
    final role = ref.watch(authControllerProvider).role;
    final tabs = TabSpec.forRole(role);

    return Scaffold(
      body: Column(
        children: [
          if (!isOnline) const _OfflineBanner(),
          Expanded(
            child: GestureDetector(
              // opaque lets the gesture fire on empty regions of a page; the
              // gesture arena still hands horizontal drags to inner
              // scrollables (e.g. horizontal lists, swipeable cards) first,
              // so this only fires when no child claims the drag.
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) {
                final dx = details.velocity.pixelsPerSecond.dx;
                final i = navigationShell.currentIndex;
                // Convention: finger LEFT (dx < 0) = advance to next tab;
                // finger RIGHT (dx > 0) = back to previous tab. Matches
                // iOS/Android page transitions.
                if (dx < -_swipeVelocityThreshold && i < tabs.length - 1) {
                  navigationShell.goBranch(i + 1);
                } else if (dx > _swipeVelocityThreshold && i > 0) {
                  navigationShell.goBranch(i - 1);
                }
              },
              child: navigationShell,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        tabs: tabs,
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

/// Spec for one bottom-nav tab.
///
/// Routes themselves are wired through GoRouter's `StatefulShellRoute`
/// (index → branch). This spec covers only the visual + semantic
/// contract for the tab button.
class TabSpec {
  const TabSpec({
    required this.outlineIcon,
    required this.filledIcon,
    required this.shortLabel,
    required this.semanticsLabel,
  });

  /// Inactive-state glyph (Phosphor Bold).
  final IconData outlineIcon;

  /// Active-state glyph (Phosphor Fill). Cross-faded in from [outlineIcon]
  /// over `AppIconTheme.fillDuration` on selection.
  final IconData filledIcon;

  /// Short label rendered under the icon. Keep ≤8 chars so two-line wrap
  /// never happens at iPhone-SE width (375 px / 5 tabs = 75 px each).
  final String shortLabel;

  /// Full-phrase label for screen readers (e.g. "My job applications" vs
  /// the short "Applied"). Not displayed visually.
  final String semanticsLabel;

  /// Role-aware tab roster — slots 2 and 3 swap by user role.
  static List<TabSpec> forRole(UserRole? role) {
    final isBuilder = role == UserRole.builder;
    return [
      const TabSpec(
        outlineIcon: AppIcons.homeOutline,
        filledIcon: AppIcons.homeFilled,
        shortLabel: 'Home',
        semanticsLabel: 'Home',
      ),
      if (isBuilder)
        const TabSpec(
          outlineIcon: AppIcons.myJobsOutline,
          filledIcon: AppIcons.myJobsFilled,
          shortLabel: 'My Jobs',
          semanticsLabel: 'My posted jobs',
        )
      else
        const TabSpec(
          outlineIcon: AppIcons.findJobsOutline,
          filledIcon: AppIcons.findJobsFilled,
          shortLabel: 'Find',
          semanticsLabel: 'Find jobs nearby',
        ),
      if (isBuilder)
        const TabSpec(
          outlineIcon: AppIcons.applicantsOutline,
          filledIcon: AppIcons.applicantsFilled,
          shortLabel: 'Applicants',
          semanticsLabel: 'Job applicants',
        )
      else
        const TabSpec(
          outlineIcon: AppIcons.appliedOutline,
          filledIcon: AppIcons.appliedFilled,
          shortLabel: 'Applied',
          semanticsLabel: 'My job applications',
        ),
      const TabSpec(
        outlineIcon: AppIcons.messagesOutline,
        filledIcon: AppIcons.messagesFilled,
        shortLabel: 'Messages',
        semanticsLabel: 'Messages',
      ),
      const TabSpec(
        outlineIcon: AppIcons.profileOutline,
        filledIcon: AppIcons.profileFilled,
        shortLabel: 'Profile',
        semanticsLabel: 'My profile',
      ),
    ];
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: c.urgentBg,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(AppIcons.wifi, size: 14.r, color: c.urgentTx),
            Gap(8.w),
            Text(
              'No internet connection',
              style: tt.bodySmall!.copyWith(
                color: c.urgentTx,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  final List<TabSpec> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(tabs.length, (i) {
            final tab = tabs[i];
            final isActive = i == currentIndex;
            final tintColor = isActive ? c.action : c.text3;

            return Expanded(
              child: Semantics(
                label: tab.semanticsLabel,
                selected: isActive,
                button: true,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTap(i);
                  },
                  child: Padding(
                    padding: EdgeInsets.only(top: 10.h, bottom: 12.h),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: AppIconTheme.fillDuration,
                          switchInCurve: AppIconTheme.fillCurve,
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                          child: Icon(
                            isActive ? tab.filledIcon : tab.outlineIcon,
                            key: ValueKey<bool>(isActive),
                            size: AppIconTheme.navSize,
                            color: tintColor,
                          ),
                        ),
                        Gap(4.h),
                        Text(
                          tab.shortLabel,
                          style: tt.labelSmall!.copyWith(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: tintColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
