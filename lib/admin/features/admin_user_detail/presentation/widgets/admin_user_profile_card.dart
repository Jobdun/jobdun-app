import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/theme/app_icons.dart';
import '../../domain/entities/admin_user_detail.dart';
import 'admin_user_kv_row.dart';

/// General profile fields: phone, licence, onboarding, timestamps.
class AdminUserProfileCard extends StatelessWidget {
  const AdminUserProfileCard({super.key, required this.detail});

  final AdminUserDetail detail;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fmt = DateFormat('d MMM y, HH:mm');

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PROFILE', style: AdminText.cardLabel(c.text3)),
          const Gap(12),
          if (detail.phone != null)
            AdminUserKvRow(
              label: 'Phone',
              valueWidget: Row(
                children: [
                  Text(detail.phone!, style: AdminText.input(c.text1)),
                  if (detail.phoneVerifiedAt != null) ...[
                    const Gap(6),
                    Icon(AppIcons.verified, size: 14, color: c.verified),
                  ],
                ],
              ),
            ),
          if (detail.licenceUrl != null)
            AdminUserKvRow(
              label: 'Licence URL',
              valueWidget: GestureDetector(
                onTap: () => launchUrl(Uri.parse(detail.licenceUrl!)),
                child: Text(
                  detail.licenceUrl!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminText.input(c.action).copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: c.action,
                  ),
                ),
              ),
            ),
          if (detail.onboardingCompletedAt != null)
            AdminUserKvRow(
              label: 'Onboarding Completed',
              value: fmt.format(detail.onboardingCompletedAt!),
            ),
          if (detail.updatedAt != null)
            AdminUserKvRow(
              label: 'Last Updated',
              value: fmt.format(detail.updatedAt!),
            ),
          if (detail.isDeleted && detail.deletedAt != null)
            AdminUserKvRow(
              label: 'Deleted At',
              valueWidget: Row(
                children: [
                  Icon(AppIcons.warning, size: 14, color: c.urgent),
                  const Gap(4),
                  Text(
                    fmt.format(detail.deletedAt!),
                    style: AdminText.bodyStrong(c.urgentTx),
                  ),
                ],
              ),
            ),
          if (_isEmpty(detail))
            Text(
              'No additional profile data.',
              style: AdminText.value(c.text3),
            ),
        ],
      ),
    );
  }

  bool _isEmpty(AdminUserDetail d) =>
      d.phone == null &&
      d.licenceUrl == null &&
      d.onboardingCompletedAt == null &&
      d.updatedAt == null &&
      !d.isDeleted;
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

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
      child: child,
    );
  }
}
