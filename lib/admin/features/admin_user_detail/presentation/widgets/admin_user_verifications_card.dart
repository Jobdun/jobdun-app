import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../domain/entities/admin_verification_summary.dart';

/// Lists the latest verification record per kind.
class AdminUserVerificationsCard extends StatelessWidget {
  const AdminUserVerificationsCard({super.key, required this.verifications});

  final List<AdminVerificationSummary> verifications;

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
          Text('VERIFICATIONS', style: AdminText.cardLabel(c.text3)),
          const Gap(12),
          if (verifications.isEmpty)
            Text('No verifications on record.', style: AdminText.value(c.text3))
          else
            ...verifications.map((v) => _VerificationRow(summary: v)),
        ],
      ),
    );
  }
}

class _VerificationRow extends StatelessWidget {
  const _VerificationRow({required this.summary});
  final AdminVerificationSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, tx) = _statusColors(summary.status, c);
    final fmt = DateFormat('d MMM y');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                summary.kind.toUpperCase(),
                style: AdminText.labelMd(
                  c.text1,
                ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.1),
              ),
              const Gap(10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  summary.status.toUpperCase(),
                  style: AdminText.eyebrow(tx).copyWith(letterSpacing: 1.1),
                ),
              ),
            ],
          ),
          if (summary.failureReason != null) ...[
            const Gap(3),
            Text(summary.failureReason!, style: AdminText.meta(c.urgentTx)),
          ],
          if (summary.updatedAt != null) ...[
            const Gap(2),
            Text(
              'Updated ${fmt.format(summary.updatedAt!)}',
              style: AdminText.eyebrow(
                c.text3,
              ).copyWith(fontWeight: FontWeight.w400, letterSpacing: 0),
            ),
          ],
        ],
      ),
    );
  }

  (Color bg, Color tx) _statusColors(String status, JColors c) =>
      switch (status.toLowerCase()) {
        'verified' => (c.verifiedBg, c.verifiedTx),
        'failed' => (c.urgentBg, c.urgentTx),
        'pending' => (c.warningBg, c.warningTx),
        _ => (c.surfaceRaised, c.text2),
      };
}
