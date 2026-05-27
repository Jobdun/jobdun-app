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
const Duration _animDuration = Duration(milliseconds: 200);
const Curve _animCurve = Curves.easeOut;

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

class _Header extends StatelessWidget {
  const _Header({required this.collapsed, required this.onToggle});

  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.fromLTRB(collapsed ? 12 : 20, 24, 12, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!collapsed)
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
            )
          else
            const Spacer(),
          Tooltip(
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
                  child: Icon(
                    AppIcons.sidebarToggle,
                    size: 16,
                    color: c.text1,
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.iconActive,
    required this.label,
    required this.isActive,
    required this.collapsed,
    required this.onTap,
  });

  final IconData icon;
  final IconData iconActive;
  final String label;
  final bool isActive;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final iconWidget = Icon(
      isActive ? iconActive : icon,
      size: 18,
      color: isActive ? c.action : c.text2,
    );

    final content = Material(
      color: isActive ? c.surfaceRaised : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: collapsed
              ? Center(child: iconWidget)
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                    ],
                  ),
                ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: collapsed ? Tooltip(message: label, child: content) : content,
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
    final button = Material(
      color: c.surfaceRaised,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: SizedBox(
          height: 44,
          child: collapsed
              ? Center(
                  child: Icon(AppIcons.signOut, size: 16, color: c.text1),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: collapsed ? Tooltip(message: 'Sign out', child: button) : button,
    );
  }
}
