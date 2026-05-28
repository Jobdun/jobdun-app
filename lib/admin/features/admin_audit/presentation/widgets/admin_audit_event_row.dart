import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../domain/entities/admin_audit_event.dart';

class AdminAuditEventRow extends StatelessWidget {
  const AdminAuditEventRow({super.key, required this.event});
  final AdminAuditEvent event;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Render timestamps in Asia/Sydney (UTC+10, no DST for v1 per spec).
    final sydney = event.occurredAt.toUtc().add(const Duration(hours: 10));
    final fmt = DateFormat('d MMM y · HH:mm');
    final actor = event.actorId == null
        ? '—'
        : '${event.actorId!.substring(0, 8)}…';
    final target = event.targetUserId == null
        ? '—'
        : '${event.targetUserId!.substring(0, 8)}…';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SourcePill(source: event.source),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.eventType.toUpperCase(),
                  style: GoogleFonts.openSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: c.text1,
                  ),
                ),
                const Gap(2),
                Text(
                  'actor $actor · target $target',
                  style: GoogleFonts.openSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: c.text2,
                  ),
                ),
                if (event.payloadPreview != null) ...[
                  const Gap(2),
                  Text(
                    event.payloadPreview!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.openSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: c.text3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Gap(12),
          Text(
            fmt.format(sydney),
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

class _SourcePill extends StatelessWidget {
  const _SourcePill({required this.source});
  final AdminAuditSource source;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (label, color) = switch (source) {
      AdminAuditSource.verification => ('VERIF', c.action),
      AdminAuditSource.role => ('ROLE', c.text2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.openSans(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: color,
        ),
      ),
    );
  }
}
