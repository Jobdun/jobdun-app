import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/design/widgets/j_button.dart';
import '../../../../../core/theme/app_icons.dart';
import '../../../../app/placeholders/admin_placeholder_action.dart';
import '../../../../app/placeholders/admin_status_tag.dart';
import '../../../../app/placeholders/placeholder_models.dart';

/// Moderation surface — tier, account state, open reports + the
/// Suspend/Ban actions. **UI-only**: every value is a [placeholderDefault]
/// and every action is disabled until Phase 2 (moderation) wires it.
class AdminUserModerationCard extends StatelessWidget {
  const AdminUserModerationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
              Text('MODERATION', style: AdminText.cardLabel(c.text3)),
              const Spacer(),
              Text(
                'PHASE 2 · NOT WIRED',
                style: AdminText.eyebrow(c.text3).copyWith(letterSpacing: 1.2),
              ),
            ],
          ),
          const Gap(12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AdminStatusTag(
                label: SubscriptionTier.placeholderDefault.label,
                tooltip: 'Subscription tier — ${AdminPhase.billing}',
              ),
              AdminStatusTag(
                label: UserModerationStatus.placeholderDefault.label,
                tooltip: 'Moderation status — ${AdminPhase.moderation}',
              ),
              AdminStatusTag(
                label: '—',
                icon: AppIcons.warning,
                tooltip: 'Open reports — ${AdminPhase.moderation}',
              ),
            ],
          ),
          const Gap(16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              SizedBox(
                width: 150,
                child: AdminPlaceholderAction(
                  label: 'SUSPEND',
                  tooltip: AdminPhase.moderationWiring,
                ),
              ),
              SizedBox(
                width: 150,
                child: AdminPlaceholderAction(
                  label: 'BAN',
                  tooltip: AdminPhase.moderationWiring,
                  variant: JButtonVariant.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
