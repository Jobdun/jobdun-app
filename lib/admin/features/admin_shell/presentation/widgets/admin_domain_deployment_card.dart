import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/theme/app_icons.dart';

/// Static deployment snapshot for the admin dashboard.
///
/// The values mirror the current repo setup and the latest manual domain
/// check: jobdun.com.au is still served by GoDaddy DPS, while the repo already
/// contains the Flutter marketing shell and Cloudflare headers. This is
/// intentionally not a monitor or backend-backed status model yet.
class AdminDomainDeploymentCard extends StatelessWidget {
  const AdminDomainDeploymentCard({super.key});

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
              Icon(AppIcons.website, size: 18, color: c.actionInk),
              const Gap(10),
              Text('DOMAIN DEPLOYMENT', style: AdminText.sectionTitle(c.text1)),
            ],
          ),
          const Gap(8),
          Text(
            'Public website, repo bundle, and admin console split.',
            style: AdminText.body(c.text2),
          ),
          const Gap(18),
          const LayoutBuilder(builder: _buildStatusGrid),
        ],
      ),
    );
  }

  static Widget _buildStatusGrid(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final wide = constraints.maxWidth >= 980;
    final width = wide ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth;
    const cards = [
      _DeploymentStatusTile(
        label: 'CURRENT LIVE',
        value: 'GoDaddy DPS placeholder detected',
        detail: 'jobdun.com.au',
        icon: AppIcons.warning,
        tone: _DeploymentTone.warning,
      ),
      _DeploymentStatusTile(
        label: 'REPO TARGET',
        value: 'Flutter web marketing bundle + Cloudflare Pages',
        detail: 'web/index.html + web/_headers',
        icon: AppIcons.document,
        tone: _DeploymentTone.ready,
      ),
      _DeploymentStatusTile(
        label: 'ADMIN TARGET',
        value: 'Cloudflare Pages project: jobdun-admin',
        detail: 'scripts/deploy-admin.sh',
        icon: AppIcons.shield,
        tone: _DeploymentTone.admin,
      ),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: cards
          .map((card) => SizedBox(width: width, child: card))
          .toList(),
    );
  }
}

enum _DeploymentTone { warning, ready, admin }

class _DeploymentStatusTile extends StatelessWidget {
  const _DeploymentStatusTile({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final _DeploymentTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final toneColor = switch (tone) {
      _DeploymentTone.warning => c.warning,
      _DeploymentTone.ready => c.verified,
      _DeploymentTone.admin => c.available,
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: toneColor),
              const Gap(8),
              Expanded(
                child: Text(
                  label,
                  style: AdminText.eyebrow(
                    toneColor,
                  ).copyWith(letterSpacing: 1.2),
                ),
              ),
            ],
          ),
          const Gap(12),
          Text(value, style: AdminText.bodyStrong(c.text1)),
          const Gap(8),
          Text(detail, style: AdminText.meta(c.text2)),
        ],
      ),
    );
  }
}
