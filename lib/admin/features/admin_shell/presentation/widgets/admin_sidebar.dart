import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/design/widgets/jobdun_logo.dart';
import '../../../../../core/theme/app_icons.dart';
import '../../../../app/placeholders/placeholder_models.dart';
import '../../../../app/router/admin_routes.dart';
import '../../../../app/widgets/admin_brand.dart';
import '../../../admin_auth/presentation/providers/admin_session_provider.dart';

const double _expandedWidth = 240;
const double _collapsedWidth = 72;
const double _outerH = 12;
const double _innerH = 12;
const double _itemHeight = 44;
const double _accentBarWidth = 3;
const Duration _animDuration = Duration(milliseconds: 200);
const Curve _animCurve = Curves.easeOut;

/// Inner row width when expanded — used to force the labelled layout to stop
/// shrinking as the AnimatedContainer interpolates its parent width during
/// collapse / expand. The outer ClipRect hides the overflow.
const double _expandedInnerWidth =
    _expandedWidth - (_outerH * 2) - (_innerH * 2);

class AdminSidebar extends ConsumerWidget {
  const AdminSidebar({
    super.key,
    required this.activeRoute,
    required this.collapsed,
    required this.onToggle,
  });

  final String activeRoute;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final session = ref
        .watch(adminSessionProvider)
        .maybeWhen(data: (s) => s, orElse: () => null);

    return AnimatedContainer(
      duration: _animDuration,
      curve: _animCurve,
      width: collapsed ? _collapsedWidth : _expandedWidth,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(collapsed: collapsed, onToggle: onToggle),
            Divider(color: c.border, height: 1),
            const Gap(8),
            _NavItem(
              icon: AppIcons.homeOutline,
              iconActive: AppIcons.homeFilled,
              label: 'DASHBOARD',
              isActive: activeRoute == AdminRoutes.dashboard,
              collapsed: collapsed,
              onTap: () => context.go(AdminRoutes.dashboard),
            ),
            _NavItem(
              icon: AppIcons.verified,
              iconActive: AppIcons.verified,
              label: 'VERIFICATIONS',
              isActive: activeRoute == AdminRoutes.verifications,
              collapsed: collapsed,
              onTap: () => context.go(AdminRoutes.verifications),
            ),
            _NavItem(
              icon: AppIcons.applicantsOutline,
              iconActive: AppIcons.applicantsFilled,
              label: 'USERS',
              isActive: activeRoute == AdminRoutes.users,
              collapsed: collapsed,
              onTap: () => context.go(AdminRoutes.users),
            ),
            _NavItem(
              icon: AppIcons.briefcase,
              iconActive: AppIcons.briefcaseFilled,
              label: 'JOBS',
              isActive: activeRoute == AdminRoutes.jobs,
              collapsed: collapsed,
              onTap: () => context.go(AdminRoutes.jobs),
            ),
            _NavItem(
              icon: AppIcons.shield,
              iconActive: AppIcons.shield,
              label: 'AUDIT LOG',
              isActive: activeRoute == AdminRoutes.audit,
              collapsed: collapsed,
              onTap: () => context.go(AdminRoutes.audit),
            ),
            // Live action — compose a push + in-app broadcast (push program
            // Stream A). Took over the former REPORTS roadmap slot.
            _NavItem(
              icon: AppIcons.send,
              iconActive: AppIcons.send,
              label: 'BROADCAST',
              isActive: activeRoute == AdminRoutes.broadcast,
              collapsed: collapsed,
              onTap: () => context.go(AdminRoutes.broadcast),
            ),
            // Roadmap surface — navigable placeholder page, marked with a lock
            // + Stage-1 milestone so the client sees what's coming.
            _NavItem(
              icon: AppIcons.budget,
              iconActive: AppIcons.budget,
              label: 'PAYMENTS',
              isActive: activeRoute == AdminRoutes.payments,
              collapsed: collapsed,
              comingSoon: true,
              tooltip: 'Payments & payouts — ${AdminPhase.payments}',
              onTap: () => context.go(AdminRoutes.payments),
            ),
            // No page yet (Phase 3, read-only tier visibility) → stays locked.
            _NavItem(
              icon: AppIcons.card,
              iconActive: AppIcons.card,
              label: 'BILLING',
              isActive: false,
              collapsed: collapsed,
              comingSoon: true,
              tooltip:
                  'Billing — ${AdminPhase.billing} · read-only tier visibility',
            ),
            const Spacer(),
            if (session != null) ...[
              Divider(color: c.border, height: 1),
              if (!collapsed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SIGNED IN AS',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: AdminText.eyebrow(c.text3),
                      ),
                      const Gap(4),
                      Text(
                        session.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: AdminText.labelMd(
                          c.text2,
                        ).copyWith(letterSpacing: 0),
                      ),
                    ],
                  ),
                )
              else
                const Gap(16),
              _SignOutButton(
                collapsed: collapsed,
                onPressed: () =>
                    ref.read(adminSessionProvider.notifier).signOut(),
              ),
              const Gap(16),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lets a fixed-natural-width child render without being squeezed by an
/// interpolated parent width. The sidebar's outer ClipRect hides any visual
/// overflow during the collapse/expand animation.
///
/// IMPORTANT: must be used inside a parent that supplies a **finite vertical
/// constraint** (e.g. a `SizedBox(height: ...)`). `OverflowBox` defaults its
/// own max height to the parent's max height — using this directly inside a
/// `Column` (where children measure with `maxHeight: Infinity`) will assert.
/// For unbounded-height callers, use plain layout with `softWrap: false` +
/// `overflow: TextOverflow.clip` on text instead.
class _ClippedExpanded extends StatelessWidget {
  const _ClippedExpanded({required this.child, this.width = _expandedWidth});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      alignment: Alignment.centerLeft,
      minWidth: 0,
      maxWidth: width,
      child: SizedBox(width: width, child: child),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.collapsed, required this.onToggle});

  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final toggleButton = Tooltip(
      message: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
      child: Material(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onToggle,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(AppIcons.sidebarToggle, size: 16, color: c.text1),
          ),
        ),
      ),
    );

    if (collapsed) {
      // Mark + toggle stacked, centered to the rail. Centers align with nav
      // icons below (both share the 36-px column center).
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
        child: Column(
          children: [
            _BrandMark(
              onTap: () => GoRouter.of(context).go(AdminRoutes.dashboard),
            ),
            const Gap(12),
            toggleButton,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => GoRouter.of(context).go(AdminRoutes.dashboard),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 2),
                child: AdminBrandLockup(badgeSize: 26),
              ),
            ),
          ),
          toggleButton,
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The universal badge is its own orange circle, so no tile behind it.
    return Tooltip(
      message: 'Dashboard',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: JobdunLogo(variant: LogoVariant.badge, height: 36),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.iconActive,
    required this.label,
    required this.isActive,
    required this.collapsed,
    this.onTap,
    this.comingSoon = false,
    this.tooltip,
  });

  final IconData icon;
  final IconData iconActive;
  final String label;
  final bool isActive;
  final bool collapsed;
  final VoidCallback? onTap;

  /// Roadmap item: shows a trailing lock + phase [tooltip]. Still navigable
  /// when [onTap] is supplied (opens a placeholder page) and highlights when
  /// active; a null [onTap] leaves it locked / non-tappable.
  final bool comingSoon;

  /// Hover copy for [comingSoon] items, e.g. 'Reports queue — Phase 2'.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final active = isActive;
    // A coming-soon item still carries the lock + phase tooltip, but it IS
    // navigable to its placeholder page and highlights when active. Only the
    // muted (inactive) colour marks it as roadmap-not-live.
    final muted = comingSoon && !active;
    final iconWidget = Icon(
      active ? iconActive : icon,
      size: 18,
      color: muted ? c.text3 : (active ? c.action : c.text2),
    );

    Widget body;
    if (collapsed) {
      body = SizedBox(
        height: _itemHeight,
        child: Center(child: iconWidget),
      );
    } else {
      body = SizedBox(
        height: _itemHeight,
        child: _ClippedExpanded(
          width: _expandedInnerWidth + (_innerH * 2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _innerH),
            child: Row(
              children: [
                iconWidget,
                const Gap(12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: AdminText.label(
                      muted ? c.text3 : (active ? c.text1 : c.text2),
                    ),
                  ),
                ),
                if (comingSoon) Icon(AppIcons.lock, size: 14, color: c.text3),
              ],
            ),
          ),
        ),
      );
    }

    final material = Material(
      color: active ? c.surfaceRaised : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: body,
      ),
    );

    // Active accent: 3px bar on the left edge, rounded to match the pill.
    final pill = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        children: [
          material,
          if (active)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _accentBarWidth,
              child: Container(color: c.action),
            ),
        ],
      ),
    );

    final showTooltip = collapsed || comingSoon;
    final tipMessage = comingSoon ? (tooltip ?? label) : label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _outerH, vertical: 2),
      child: showTooltip ? Tooltip(message: tipMessage, child: pill) : pill,
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.collapsed, required this.onPressed});

  final bool collapsed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final inner = collapsed
        ? SizedBox(
            height: _itemHeight,
            child: Center(
              child: Icon(AppIcons.signOut, size: 16, color: c.text1),
            ),
          )
        : SizedBox(
            height: _itemHeight,
            child: _ClippedExpanded(
              width: _expandedInnerWidth + (_innerH * 2),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _innerH),
                child: Row(
                  children: [
                    Icon(AppIcons.signOut, size: 16, color: c.text1),
                    const Gap(10),
                    Expanded(
                      child: Text(
                        'SIGN OUT',
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: AdminText.label(c.text1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

    final material = Material(
      color: c.surfaceRaised,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: inner,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _outerH),
      child: collapsed
          ? Tooltip(message: 'Sign out', child: material)
          : material,
    );
  }
}
