import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/theme/app_icons.dart';
import '../providers/admin_verifications_provider.dart';

/// U4.1: triage buckets against the user-facing "reviewed within 24 hours"
/// promise. Amber from 18 h (running out of runway), breached past 24 h.
enum QueueAge { fresh, warning, breached }

QueueAge queueAgeFor(Duration inQueue) => inQueue >= const Duration(hours: 24)
    ? QueueAge.breached
    : inQueue >= const Duration(hours: 18)
    ? QueueAge.warning
    : QueueAge.fresh;

String queueAgeLabel(Duration inQueue) => inQueue < const Duration(hours: 1)
    ? '${inQueue.inMinutes} min in queue'
    : '${inQueue.inHours} h in queue';

/// Compact row for the admin verification queue. Extracted to keep the page
/// file under the 500-LOC ceiling.
class AdminVerificationQueueRow extends StatelessWidget {
  const AdminVerificationQueueRow({
    super.key,
    required this.item,
    required this.onTap,
    this.now,
  });

  final AdminVerificationItem item;
  final VoidCallback onTap;

  /// Injectable clock for tests; defaults to [DateTime.now].
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final claim = _claimSummary(item);
    final apiFailure = item.lastVerificationFailureReason;
    final inQueue = (now ?? DateTime.now()).difference(item.submittedAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminVerificationStatusDot(status: item.status),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _KindBadge(kind: item.kind, state: item.state),
                          const Gap(8),
                          _RoleTag(role: item.roleLabel),
                        ],
                      ),
                      const Gap(6),
                      Text(
                        item.displayName,
                        style: AdminText.body(
                          c.text1,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (claim != null) ...[
                        const Gap(2),
                        Text(claim, style: AdminText.meta(c.text2)),
                      ],
                      const Gap(2),
                      Text(
                        'submitted ${_fmt(item.submittedAt)}',
                        style: AdminText.caption(c.text3),
                      ),
                      if (item.status == 'pending') ...[
                        const Gap(4),
                        _AgeIndicator(inQueue: inQueue),
                      ],
                      if (apiFailure != null) ...[
                        const Gap(6),
                        _ApiFailureLine(detail: apiFailure),
                      ],
                    ],
                  ),
                ),
                Text(
                  item.status.toUpperCase(),
                  style: AdminText.caption(
                    _statusColor(context, item.status),
                  ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
                ),
                const Gap(12),
                Icon(AppIcons.chevronRight, color: c.text3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String? _claimSummary(AdminVerificationItem i) {
    final parts = <String>[];
    if (i.documentNumber != null) parts.add('#${i.documentNumber}');
    if (i.expiryDate != null) {
      parts.add('expires ${DateFormat('d MMM yyyy').format(i.expiryDate!)}');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String _fmt(DateTime t) => DateFormat('d MMM yyyy · HH:mm').format(t);

  static Color _statusColor(BuildContext context, String status) {
    final c = context.c;
    return switch (status) {
      'pending' => c.warning,
      'approved' => c.verified,
      'rejected' => c.urgent,
      'expired' => c.text3,
      _ => c.text3,
    };
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind, this.state});
  final AdminVerificationKind kind;
  final String? state;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // U4.3: amber is status-only in this queue (pending dot + age chip) —
    // a WHITE CARD kind badge in warning amber read as "this row is pending"
    // regardless of its actual status. Categories use non-status colours.
    final (label, bg, tx) = switch (kind) {
      AdminVerificationKind.tradeLicence => (
        'TRADE LICENCE',
        c.actionBg,
        c.actionTx,
      ),
      AdminVerificationKind.builderAbn => (
        'BUILDER ABN',
        c.verifiedBg,
        c.verifiedTx,
      ),
      AdminVerificationKind.whiteCard => (
        'WHITE CARD',
        c.availableBg,
        c.availableTx,
      ),
      AdminVerificationKind.publicLiability => (
        'INSURANCE',
        c.surfaceRaised,
        c.text1,
      ),
      AdminVerificationKind.other => ('OTHER', c.surfaceRaised, c.text1),
    };
    final text = state != null ? '$label · $state' : label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: AdminText.eyebrow(tx).copyWith(letterSpacing: 0.8),
      ),
    );
  }
}

/// U4.1: time-in-queue indicator on pending rows. Fresh rows get a quiet
/// caption; from 18 h the row carries an amber chip; past the promised 24 h
/// it goes red and says so. Reviewers triage against the SLA at a glance.
class _AgeIndicator extends StatelessWidget {
  const _AgeIndicator({required this.inQueue});

  final Duration inQueue;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final age = queueAgeFor(inQueue);
    if (age == QueueAge.fresh) {
      return Text(queueAgeLabel(inQueue), style: AdminText.caption(c.text3));
    }
    final (bg, tx, label) = age == QueueAge.breached
        ? (c.urgentBg, c.urgentTx, 'SLA BREACHED · ${queueAgeLabel(inQueue)}')
        : (c.warningBg, c.warningTx, queueAgeLabel(inQueue));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: AdminText.eyebrow(tx).copyWith(letterSpacing: 0.6),
      ),
    );
  }
}

class _RoleTag extends StatelessWidget {
  const _RoleTag({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        'ROLE: $role',
        style: AdminText.eyebrow(c.text3).copyWith(letterSpacing: 0.8),
      ),
    );
  }
}

class _ApiFailureLine extends StatelessWidget {
  const _ApiFailureLine({required this.detail});
  final String detail;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.urgent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.warning, size: 14, color: c.urgent),
          const Gap(6),
          Expanded(
            child: Text(
              'API attempt failed: $detail',
              style: AdminText.caption(c.urgent),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminVerificationStatusDot extends StatelessWidget {
  const AdminVerificationStatusDot({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = switch (status) {
      'pending' => c.warning,
      'approved' => c.verified,
      'rejected' => c.urgent,
      _ => c.text3,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
