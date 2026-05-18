import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/constants/app_constants.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/theme/app_selection.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/tab_spec.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineAsync = ref.watch(_connectivityProvider);
    final isOnline = onlineAsync.asData?.value ?? true;
    final UserRole? role = ref.watch(
      authControllerProvider.select((s) => s.role),
    );

    return Scaffold(
      body: Column(
        children: [
          if (!isOnline) const _OfflineBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: navigationShell.currentIndex,
        tabs: TabSpec.forRole(role),
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
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
            Icon(Iconsax.wifi, size: AppIconSize.xs.r, color: c.urgentTx),
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

/// Trade-side bottom navigation: 5 labelled, icon-over-label tabs that swap
/// the Iconsax outline→Bold variant and tween color+weight on selection.
/// Public for widget testing.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<TabSpec> tabs;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        // The tab bar is fixed-height chrome — clamp label scaling so a large
        // system text size can never overflow or grow the bar.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: Container(
            height: 56.h,
            constraints: BoxConstraints(minHeight: AppTouchTarget.min),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final tab = tabs[i];
                final isActive = i == currentIndex;
                final color = isActive
                    ? AppSelection.activeColor(c)
                    : AppSelection.inactiveColor(c);
                return Expanded(
                  child: Semantics(
                    label: tab.semanticLabel,
                    button: true,
                    selected: isActive,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: ExcludeSemantics(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isActive ? tab.iconFilled : tab.iconOutline,
                                size: AppIconSize.lg.r,
                                color: color,
                              ),
                              Gap(AppSpacing.xs.h),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs.w,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: AnimatedDefaultTextStyle(
                                    duration: AppSelection.duration,
                                    curve: AppSelection.curve,
                                    style: tt.labelSmall!.copyWith(
                                      color: color,
                                      fontWeight: isActive
                                          ? AppSelection.activeWeight
                                          : AppSelection.inactiveWeight,
                                    ),
                                    child: Text(
                                      tab.label,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
