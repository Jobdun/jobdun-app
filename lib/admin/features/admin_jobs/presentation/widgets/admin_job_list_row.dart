import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
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
                  style: GoogleFonts.openSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.text1,
                  ),
                ),
                const Gap(2),
                Text(
                  '${row.builderDisplayName} · ${row.applicationCount} $applicants',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.openSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: c.text2,
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
          _StatusPill(status: row.status),
          const Gap(12),
          Text(
            DateFormat('d MMM y').format(row.createdAt),
            style: GoogleFonts.openSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: c.text2,
            ),
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
        style: GoogleFonts.openSans(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: fg,
        ),
      ),
    );
  }
}
