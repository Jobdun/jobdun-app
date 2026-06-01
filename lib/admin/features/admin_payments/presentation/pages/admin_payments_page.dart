import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/design/widgets/j_button.dart';
import '../../../../../core/theme/app_icons.dart';
import '../../../../app/placeholders/admin_placeholder_action.dart';
import '../../../../app/placeholders/admin_placeholder_stat.dart';
import '../../../../app/placeholders/admin_roadmap_card.dart';
import '../../../../app/placeholders/placeholder_models.dart';
import '../../../../app/router/admin_routes.dart';
import '../../../admin_shell/presentation/widgets/admin_scaffold.dart';

/// Roadmap placeholder for the payments + payouts admin surface
/// (Stage 1 · M5, depends on the payments rail). UI-only — no data, no
/// backend. Metrics are em-dashes; the refund action is disabled.
class AdminPaymentsPage extends StatelessWidget {
  const AdminPaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AdminScaffold(
      title: 'PAYMENTS',
      activeRoute: AdminRoutes.payments,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PAYMENTS & PAYOUTS', style: AdminText.display(c.text1)),
            const Gap(8),
            Text(
              'Marketplace payments, trade payouts, and refunds, once the '
              'payments rail (Stripe Connect) is live.',
              style: AdminText.body(c.text2),
            ),
            const Gap(28),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.lock, size: 12, color: c.text3),
                const Gap(6),
                Text(
                  AdminPhase.payments.toUpperCase(),
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
                    label: 'TOTAL PROCESSED',
                    phase: 'M5',
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: AdminPlaceholderStat(
                    label: 'PENDING PAYOUTS',
                    phase: 'M5',
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: AdminPlaceholderStat(
                    label: 'REFUNDS (30D)',
                    phase: 'M5',
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: AdminPlaceholderStat(label: 'DISPUTES', phase: 'M5'),
                ),
              ],
            ),
            const Gap(28),
            const AdminRoadmapCard(
              label: 'TRANSACTIONS',
              note:
                  'Completed-job payments, payouts, and refunds list here, each '
                  'linked to its job and parties.',
              action: AdminPlaceholderAction(
                label: 'ISSUE REFUND',
                tooltip: AdminPhase.paymentsWiring,
                variant: JButtonVariant.danger,
              ),
            ),
            const Gap(40),
          ],
        ),
      ),
    );
  }
}
