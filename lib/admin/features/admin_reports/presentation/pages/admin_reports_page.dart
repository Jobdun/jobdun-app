import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/theme/app_icons.dart';
import '../../../../app/placeholders/admin_placeholder_action.dart';
import '../../../../app/placeholders/admin_placeholder_stat.dart';
import '../../../../app/placeholders/admin_roadmap_card.dart';
import '../../../../app/placeholders/placeholder_models.dart';
import '../../../../app/router/admin_routes.dart';
import '../../../admin_shell/presentation/widgets/admin_scaffold.dart';

/// Roadmap placeholder for the community moderation reports queue
/// (Stage 1 · M4). UI-only — no data, no backend. Shows the client what the
/// surface becomes; the metrics are em-dashes and the action is disabled.
class AdminReportsPage extends StatelessWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AdminScaffold(
      title: 'REPORTS',
      activeRoute: AdminRoutes.reports,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MODERATION REPORTS', style: AdminText.display(c.text1)),
            const Gap(8),
            Text(
              'Users and jobs flagged by the community queue here for review '
              'and resolution.',
              style: AdminText.body(c.text2),
            ),
            const Gap(28),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.lock, size: 12, color: c.text3),
                const Gap(6),
                Text(
                  AdminPhase.reports.toUpperCase(),
                  style: AdminText.eyebrow(
                    c.text3,
                  ).copyWith(letterSpacing: 1.2),
                ),
              ],
            ),
            const Gap(12),
            const Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 240,
                  child: AdminPlaceholderStat(
                    label: 'OPEN REPORTS',
                    phase: 'M4',
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: AdminPlaceholderStat(
                    label: 'AWAITING REVIEW',
                    phase: 'M4',
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: AdminPlaceholderStat(
                    label: 'RESOLVED (7D)',
                    phase: 'M4',
                  ),
                ),
              ],
            ),
            const Gap(28),
            const AdminRoadmapCard(
              label: 'REPORT QUEUE',
              note:
                  'Flagged users and jobs list here with reason, reporter, and '
                  'a one-tap resolve or dismiss, each landing in the audit log.',
              action: AdminPlaceholderAction(
                label: 'REVIEW',
                tooltip: AdminPhase.reportsWiring,
              ),
            ),
            const Gap(40),
          ],
        ),
      ),
    );
  }
}
