import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../core/theme/app_icons.dart';
import '../../../../app/router/admin_routes.dart';
import '../widgets/admin_scaffold.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return AdminScaffold(
      title: 'DASHBOARD',
      activeRoute: AdminRoutes.dashboard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WELCOME, ADMIN.',
            style: GoogleFonts.oswald(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: c.text1,
            ),
          ),
          const Gap(8),
          Text(
            'Tools and dashboards will appear here as we build them. For now, the shell is yours.',
            style: GoogleFonts.openSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.5,
              color: c.text2,
            ),
          ),
          const Gap(40),
          const _PlaceholderGrid(),
        ],
      ),
    );
  }
}

class _PlaceholderGrid extends StatelessWidget {
  const _PlaceholderGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth >= 880;
        final cards = const [
          _ComingSoonCard(
            icon: AppIcons.applicantsOutline,
            title: 'USERS',
            copy: 'Search profiles, inspect role history, suspend accounts.',
          ),
          _ComingSoonCard(
            icon: AppIcons.verified,
            title: 'VERIFICATION QUEUE',
            copy:
                'Review pending verification documents from trades. Approve or reject.',
            route: AdminRoutes.verifications,
          ),
          _ComingSoonCard(
            icon: AppIcons.briefcase,
            title: 'JOBS',
            copy: 'Moderate reported jobs and inspect lifecycle transitions.',
          ),
          _ComingSoonCard(
            icon: AppIcons.shield,
            title: 'AUDIT LOG',
            copy: 'Role changes, sign-in attempts, and other security events.',
          ),
        ];
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards
              .map(
                (card) => SizedBox(
                  width: twoCol
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth,
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({
    required this.icon,
    required this.title,
    required this.copy,
    this.route,
  });

  final IconData icon;
  final String title;
  final String copy;

  /// When set, the card becomes a real entry-point and the "COMING SOON"
  /// chip is replaced with "OPEN →". Used as features come online.
  final String? route;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isLive = route != null;
    final body = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: c.text2),
              const Gap(10),
              Text(
                title,
                style: GoogleFonts.openSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: c.text1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isLive
                      ? c.action.withValues(alpha: 0.18)
                      : c.surfaceRaised,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isLive ? 'OPEN →' : 'COMING SOON',
                  style: GoogleFonts.openSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: isLive ? c.action : c.text3,
                  ),
                ),
              ),
            ],
          ),
          const Gap(12),
          Text(
            copy,
            style: GoogleFonts.openSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.5,
              color: c.text2,
            ),
          ),
        ],
      ),
    );
    if (!isLive) return body;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => GoRouter.of(context).go(route!),
        child: body,
      ),
    );
  }
}
