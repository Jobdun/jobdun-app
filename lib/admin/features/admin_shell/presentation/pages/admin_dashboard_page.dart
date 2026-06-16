import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/theme/app_icons.dart';
import '../../../../app/placeholders/admin_placeholder_stat.dart';
import '../../../../app/router/admin_routes.dart';
import '../../../admin_dashboard/presentation/providers/admin_dashboard_stats_provider.dart';
import '../widgets/admin_domain_deployment_card.dart';
import '../widgets/admin_scaffold.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return AdminScaffold(
      title: 'DASHBOARD',
      activeRoute: AdminRoutes.dashboard,
      trailing: [
        IconButton(
          tooltip: 'Refresh stats',
          onPressed: () =>
              ref.read(adminDashboardStatsProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WELCOME, ADMIN.', style: AdminText.display(c.text1)),
            const Gap(8),
            Text(
              'Platform health at a glance. Jump into a queue below — the '
              'verification backlog is the one to keep at zero.',
              style: AdminText.body(c.text2),
            ),
            const Gap(32),
            const _StatsStrip(),
            const Gap(36),
            const AdminDomainDeploymentCard(),
            const Gap(36),
            const _ComingSoonStatsStrip(),
            const Gap(40),
            const _QuickNavGrid(),
          ],
        ),
      ),
    );
  }
}

class _StatsStrip extends ConsumerWidget {
  const _StatsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminDashboardStatsProvider);
    final stats = statsAsync.value;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tiles = [
          _StatTile(
            label: 'TOTAL USERS',
            value: _format(stats?.totalUsers, statsAsync),
            sublabel: 'Builders + Trades',
          ),
          _StatTile(
            label: 'PENDING VERIFICATIONS',
            value: _format(stats?.pendingVerifications, statsAsync),
            sublabel: 'Awaiting review',
            highlight: true,
          ),
          _StatTile(
            label: 'OPEN JOBS',
            value: _format(stats?.openJobs, statsAsync),
            sublabel: 'Across all builders',
          ),
          _StatTile(
            label: 'REJECTED (7D)',
            value: _format(stats?.rejectedLast7Days, statsAsync),
            sublabel: 'Verifications rejected this week',
          ),
        ];

        // 4 across when ≥1100, 2 across when ≥720, 1 across otherwise.
        final cols = constraints.maxWidth >= 1100
            ? 4
            : (constraints.maxWidth >= 720 ? 2 : 1);
        const spacing = 16.0;
        final tileWidth =
            (constraints.maxWidth - (spacing * (cols - 1))) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: tiles
              .map((t) => SizedBox(width: tileWidth, child: t))
              .toList(),
        );
      },
    );
  }

  static String _format(int? value, AsyncValue<Object?> async) {
    if (async.isLoading) return '…';
    if (async.hasError) return '—';
    if (value == null) return '—';
    return NumberFormat.decimalPattern().format(value);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.sublabel,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String sublabel;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? c.action.withValues(alpha: 0.4) : c.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AdminText.eyebrow(highlight ? c.action : c.text3)),
          const Gap(10),
          Text(value, style: AdminText.statValue(c.text1)),
          const Gap(4),
          Text(
            sublabel,
            style: AdminText.caption(
              c.text2,
            ).copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Placeholder metrics for queues that light up in later phases. Rendered in a
/// deliberately recessive treatment — transparent fill, em-dash value, a lock,
/// and a "PHASE X" eyebrow — so they can't be mistaken for the live stats
/// above. No data is fetched; nothing here touches the backend.
class _ComingSoonStatsStrip extends StatelessWidget {
  const _ComingSoonStatsStrip();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.lock, size: 12, color: c.text3),
            const Gap(6),
            Text(
              'COMING SOON',
              style: AdminText.eyebrow(c.text3).copyWith(letterSpacing: 1.6),
            ),
          ],
        ),
        const Gap(12),
        LayoutBuilder(
          builder: (context, constraints) {
            const tiles = [
              AdminPlaceholderStat(
                label: 'VERIFICATION QUEUE DEPTH',
                phase: 'PHASE 2',
              ),
              AdminPlaceholderStat(label: 'OPEN REPORTS', phase: 'PHASE 2'),
              AdminPlaceholderStat(label: 'SUSPENDED USERS', phase: 'PHASE 2'),
              AdminPlaceholderStat(
                label: 'ACTIVE SUBSCRIPTIONS',
                phase: 'PHASE 3',
              ),
            ];
            final cols = constraints.maxWidth >= 1100
                ? 4
                : (constraints.maxWidth >= 720 ? 2 : 1);
            const spacing = 16.0;
            final tileWidth =
                (constraints.maxWidth - (spacing * (cols - 1))) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: tiles
                  .map((t) => SizedBox(width: tileWidth, child: t))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _QuickNavGrid extends StatelessWidget {
  const _QuickNavGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth >= 880;
        final cards = const [
          _QuickNavCard(
            icon: AppIcons.verified,
            title: 'VERIFICATION QUEUE',
            copy:
                'Review pending documents from trades and builders. Approve, '
                'reject, or revoke.',
            route: AdminRoutes.verifications,
          ),
          _QuickNavCard(
            icon: AppIcons.applicantsOutline,
            title: 'USERS',
            copy:
                'Search profiles, inspect role history, and open user detail.',
            route: AdminRoutes.users,
          ),
          _QuickNavCard(
            icon: AppIcons.briefcase,
            title: 'JOBS',
            copy: 'Moderate reported jobs and inspect lifecycle transitions.',
            route: AdminRoutes.jobs,
          ),
          _QuickNavCard(
            icon: AppIcons.shield,
            title: 'AUDIT LOG',
            copy: 'Role changes, sign-in attempts, and other security events.',
            route: AdminRoutes.audit,
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

class _QuickNavCard extends StatelessWidget {
  const _QuickNavCard({
    required this.icon,
    required this.title,
    required this.copy,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String copy;
  final String route;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => GoRouter.of(context).go(route),
        child: Container(
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
                    style: AdminText.label(
                      c.text1,
                    ).copyWith(letterSpacing: 1.4),
                  ),
                  const Spacer(),
                  Text('OPEN →', style: AdminText.eyebrow(c.action)),
                ],
              ),
              const Gap(12),
              Text(copy, style: AdminText.value(c.text2)),
            ],
          ),
        ),
      ),
    );
  }
}
