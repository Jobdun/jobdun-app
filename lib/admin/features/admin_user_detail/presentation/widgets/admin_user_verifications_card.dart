import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
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
          Text(
            'VERIFICATIONS',
            style: GoogleFonts.oswald(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: c.text3,
            ),
          ),
          const Gap(12),
          if (verifications.isEmpty)
            Text(
              'No verifications on record.',
              style: GoogleFonts.openSans(fontSize: 13, color: c.text3),
            )
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
                style: GoogleFonts.openSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: c.text1,
                ),
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
                  style: GoogleFonts.openSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: tx,
                  ),
                ),
              ),
            ],
          ),
          if (summary.failureReason != null) ...[
            const Gap(3),
            Text(
              summary.failureReason!,
              style: GoogleFonts.openSans(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: c.urgentTx,
              ),
            ),
          ],
          if (summary.updatedAt != null) ...[
            const Gap(2),
            Text(
              'Updated ${fmt.format(summary.updatedAt!)}',
              style: GoogleFonts.openSans(fontSize: 10, color: c.text3),
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
        'pending' => (c.actionBg, c.actionTx),
        _ => (c.surfaceRaised, c.text2),
      };
}
