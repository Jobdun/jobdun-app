import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../domain/entities/admin_job_row.dart';

class AdminJobListRow extends StatelessWidget {
  const AdminJobListRow({super.key, required this.row});
  final AdminJobRow row;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final applicants = row.applicationCount == 1 ? 'applicant' : 'applicants';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminText.body(
                    c.text1,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const Gap(2),
                Text(
                  '${row.builderDisplayName} · ${row.applicationCount} $applicants',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminText.caption(
                    c.text2,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const Gap(12),
          _StatusPill(status: row.status),
          const Gap(12),
          Text(
            DateFormat('d MMM y').format(row.createdAt),
            style: AdminText.caption(
              c.text2,
            ).copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isOpen = status == 'open';
    final Color bg = isOpen ? c.action : c.surfaceRaised;
    final Color fg = isOpen ? c.background : c.text1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: AdminText.eyebrow(fg).copyWith(letterSpacing: 1.2),
      ),
    );
  }
}
