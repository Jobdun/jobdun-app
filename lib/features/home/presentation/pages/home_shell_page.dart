import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/theme/app_colors.dart';

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

    return Scaffold(
      body: Column(
        children: [
          if (!isOnline) const _OfflineBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: navigationShell.currentIndex,
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
            Icon(Iconsax.wifi, size: 14.r, color: c.urgentTx),
            SizedBox(width: 8.w),
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
  const _BottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _tabs = [
    (Iconsax.home_2,        Iconsax.home_25),
    (Iconsax.briefcase,     Iconsax.briefcase5),
    (Iconsax.document_text, Iconsax.document_text1),
    (Iconsax.message,       Iconsax.message5),
    (Iconsax.user,          Iconsax.user5),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Container(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52.h,
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final isActive = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Center(
                    child: Icon(
                      isActive ? tab.$2 : tab.$1,
                      size: 22.r,
                      color: isActive ? c.action : c.text3,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
