import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../core/theme/app_icons.dart';
import '../../../../app/router/admin_routes.dart';
import '../../../admin_auth/presentation/providers/admin_session_provider.dart';

const double _expandedWidth = 240;
const double _collapsedWidth = 72;
const double _outerH = 12;
const double _innerH = 12;
const double _itemHeight = 44;
const Duration _animDuration = Duration(milliseconds: 200);
const Curve _animCurve = Curves.easeOut;

/// Natural width of expanded-row content (icon + gap + label area). Fed into
/// the OverflowBox + SizedBox pattern so the inner Row lays out at this fixed
/// width regardless of the AnimatedContainer's interpolated parent width —
/// the outer ClipRect hides the overflow during animation.
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
              comingSoon: true,
              onTap: () => context.go(AdminRoutes.users),
            ),
            _NavItem(
              icon: AppIcons.briefcase,
              iconActive: AppIcons.briefcaseFilled,
              label: 'JOBS',
              isActive: activeRoute == AdminRoutes.jobs,
              collapsed: collapsed,
              comingSoon: true,
              onTap: () => context.go(AdminRoutes.jobs),
            ),
            _NavItem(
              icon: AppIcons.shield,
              iconActive: AppIcons.shield,
              label: 'AUDIT LOG',
              isActive: activeRoute == AdminRoutes.audit,
              collapsed: collapsed,
              comingSoon: true,
              onTap: () => context.go(AdminRoutes.audit),
            ),
            const Spacer(),
            if (session != null) ...[
              Divider(color: c.border, height: 1),
              if (!collapsed)
                _ClippedExpanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SIGNED IN AS',
                          style: GoogleFonts.openSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: c.text3,
                          ),
                        ),
                        const Gap(4),
                        Text(
                          session.email,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.openSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.text2,
                          ),
                        ),
                      ],
                    ),
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

/// Helper that lets a fixed-natural-width child render without being squeezed
/// by an interpolated parent width. Outer ClipRect on the sidebar hides any
/// overflow during the collapse/expand animation.
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
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 20),
        child: Center(child: toggleButton),
      );
    }

    return _ClippedExpanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 12, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'JOBDUN',
                    style: GoogleFonts.oswald(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: c.text1,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    'ADMIN',
                    style: GoogleFonts.openSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: c.action,
                    ),
                  ),
                ],
              ),
            ),
            toggleButton,
          ],
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
    required this.onTap,
    this.comingSoon = false,
  });

  final IconData icon;
  final IconData iconActive;
  final String label;
  final bool isActive;
  final bool collapsed;
  final VoidCallback onTap;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final iconWidget = Icon(
      isActive ? iconActive : icon,
      size: 18,
      color: isActive ? c.action : c.text2,
    );

    Widget body;
    if (collapsed) {
      body = SizedBox(
        height: _itemHeight,
        child: Stack(
          children: [
            Center(child: iconWidget),
            if (comingSoon)
              Positioned(
                top: 8,
                right: 10,
                child: _ComingSoonDot(color: c.action),
              ),
          ],
        ),
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
                    style: GoogleFonts.openSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isActive ? c.text1 : c.text2,
                    ),
                  ),
                ),
                if (comingSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceRaised,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'SOON',
                      style: GoogleFonts.openSans(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: c.text3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final material = Material(
      color: isActive ? c.surfaceRaised : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: body,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _outerH, vertical: 2),
      child: collapsed
          ? Tooltip(message: label, child: material)
          : material,
    );
  }
}

class _ComingSoonDot extends StatelessWidget {
  const _ComingSoonDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
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
                        style: GoogleFonts.openSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: c.text1,
                        ),
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
