import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design/colors.dart';
import '../../../../app/theme/breakpoints.dart';
import '../providers/nav_scroll_provider.dart';
import '../widgets/site_brand_lockup.dart';
import '../widgets/theme_toggle.dart';
import 'site_top_nav_link.dart';

/// Floating frosted-glass, router-aware top bar shared by every page.
///
/// - A pill inset from the viewport edges with a `BackdropFilter` blur so
///   content scrolls *through* it. Transparent at the very top; frosted +
///   hairline border once content scrolls under it ([navScrolledProvider]).
/// - The J mark (left) returns home. On tablet+ the section links route via
///   GoRouter and the current route highlights; on phones they collapse into a
///   menu. The orange CONTACT US button is the standing call-to-action.
class SiteTopBar extends ConsumerWidget {
  const SiteTopBar({super.key});

  static const _links = <({String label, String route})>[
    (label: 'FOR BUILDERS', route: '/for-builders'),
    (label: 'FOR CREWS', route: '/for-crews'),
    (label: 'PRICING', route: '/pricing'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final scrolled = ref.watch(navScrolledProvider);
    final wide = MediaQuery.sizeOf(context).width >= Bp.laptop;
    final path = GoRouterState.of(context).uri.path;

    final fill = scrolled
        ? c.surface.withValues(alpha: 0.78)
        : c.background.withValues(alpha: 0.0);
    final borderColor = scrolled ? c.border : Colors.transparent;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _hPad(context),
          AppSpacing.md.h,
          _hPad(context),
          0,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card.r),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(AppRadius.card.r),
                    border: Border.all(color: borderColor),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg.w,
                    vertical: AppSpacing.sm.h,
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => context.go('/'),
                        borderRadius: BorderRadius.circular(8),
                        child: Semantics(
                          label: 'Jobdun: home',
                          button: true,
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.xs.w),
                            child: const SiteBrandLockup(height: 34),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (wide) ...[
                        for (final link in _links) ...[
                          SiteTopNavLink(
                            label: link.label,
                            active: path == link.route,
                            onTap: () => context.go(link.route),
                          ),
                          Gap(AppSpacing.lg.w),
                        ],
                        const ThemeToggle(),
                        Gap(AppSpacing.md.w),
                        _ContactCta(active: path == '/contact'),
                      ] else ...[
                        const ThemeToggle(),
                        Gap(AppSpacing.sm.w),
                        _NavMenu(currentPath: path),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _hPad(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= Bp.desktop) return AppSpacing.xl.w;
  if (w >= Bp.tablet) return AppSpacing.lg.w;
  return AppSpacing.md.w;
}

/// Orange CONTACT US button, the standing call-to-action in the bar.
class _ContactCta extends StatelessWidget {
  const _ContactCta({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: c.action,
      borderRadius: BorderRadius.circular(AppRadius.btn.r),
      child: InkWell(
        onTap: () => context.go('/contact'),
        borderRadius: BorderRadius.circular(AppRadius.btn.r),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w,
            vertical: AppSpacing.sm.h,
          ),
          child: Text(
            'CONTACT US',
            style: tt.labelLarge!.copyWith(color: c.onAction),
          ),
        ),
      ),
    );
  }
}

/// Phone-width navigation: collapses the section links + Contact into a menu.
class _NavMenu extends StatelessWidget {
  const _NavMenu({required this.currentPath});

  final String currentPath;

  static const _items = <({String label, String route})>[
    (label: 'For builders', route: '/for-builders'),
    (label: 'For crews', route: '/for-crews'),
    (label: 'Pricing', route: '/pricing'),
    (label: 'Contact us', route: '/contact'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return PopupMenuButton<String>(
      tooltip: 'Menu',
      icon: Icon(Icons.menu_rounded, color: c.text1),
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: c.border),
      ),
      onSelected: context.go,
      itemBuilder: (context) => [
        for (final item in _items)
          PopupMenuItem<String>(
            value: item.route,
            child: Text(
              item.label,
              style: tt.titleSmall!.copyWith(
                color: currentPath == item.route ? c.actionInk : c.text1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
