import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../core/theme/app_icons.dart';
import '../../../../app/router/admin_routes.dart';
import '../../../admin_auth/presentation/providers/admin_session_provider.dart';

class AdminSidebar extends ConsumerWidget {
  const AdminSidebar({super.key, required this.activeRoute});

  final String activeRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final session = ref
        .watch(adminSessionProvider)
        .maybeWhen(data: (s) => s, orElse: () => null);

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
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
                const Gap(4),
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
          Divider(color: c.border, height: 1),
          const Gap(8),
          _NavItem(
            icon: AppIcons.homeOutline,
            iconActive: AppIcons.homeFilled,
            label: 'DASHBOARD',
            route: AdminRoutes.dashboard,
            isActive: activeRoute == AdminRoutes.dashboard,
            onTap: () => context.go(AdminRoutes.dashboard),
          ),
          _NavItem(
            icon: AppIcons.verified,
            iconActive: AppIcons.verified,
            label: 'VERIFICATIONS',
            route: AdminRoutes.verifications,
            isActive: activeRoute == AdminRoutes.verifications,
            onTap: () => context.go(AdminRoutes.verifications),
          ),
          const Spacer(),
          if (session != null) ...[
            Divider(color: c.border, height: 1),
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
            ),
            _SignOutButton(
              onPressed: () =>
                  ref.read(adminSessionProvider.notifier).signOut(),
            ),
            const Gap(16),
          ],
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
    required this.route,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData iconActive;
  final String label;
  final String route;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isActive ? c.surfaceRaised : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isActive ? iconActive : icon,
                  size: 18,
                  color: isActive ? c.action : c.text2,
                ),
                const Gap(12),
                Text(
                  label,
                  style: GoogleFonts.openSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: isActive ? c.text1 : c.text2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(AppIcons.signOut, size: 16, color: c.text1),
                const Gap(10),
                Text(
                  'SIGN OUT',
                  style: GoogleFonts.openSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: c.text1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
