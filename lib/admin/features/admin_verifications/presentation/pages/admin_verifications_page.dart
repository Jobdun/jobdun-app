import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../app/router/admin_routes.dart';
import '../../../admin_shell/presentation/widgets/admin_scaffold.dart';
import '../providers/admin_verifications_provider.dart';
import '../widgets/admin_verification_review_sheet.dart';

/// Verification queue surface for admins. Lists every document submitted via
/// the wizard's manual-upload fallback, newest first; tap a row to open the
/// review sheet, view the image, and approve / reject.
class AdminVerificationsPage extends ConsumerWidget {
  const AdminVerificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final async = ref.watch(adminVerificationsProvider);
    return AdminScaffold(
      title: 'VERIFICATIONS',
      activeRoute: AdminRoutes.verifications,
      trailing: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () =>
              ref.read(adminVerificationsProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBlock(error: e.toString()),
        data: (items) {
          final pending = items.where((i) => i.status == 'pending').toList();
          final reviewed = items.where((i) => i.status != 'pending').toList();
          if (items.isEmpty) {
            return _EmptyBlock();
          }
          return ListView(
            children: [
              _SectionHeader(
                title: 'PENDING',
                count: pending.length,
                accent: c.action,
              ),
              const Gap(8),
              ...pending.map(
                (i) => _QueueRow(item: i, onTap: () => _openSheet(context, i)),
              ),
              const Gap(24),
              _SectionHeader(
                title: 'REVIEWED',
                count: reviewed.length,
                accent: c.text3,
              ),
              const Gap(8),
              ...reviewed.map(
                (i) => _QueueRow(item: i, onTap: () => _openSheet(context, i)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, AdminVerificationItem item) {
    return showDialog<void>(
      context: context,
      builder: (_) => AdminVerificationReviewSheet(item: item),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.accent,
  });

  final String title;
  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.oswald(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: c.text1,
          ),
        ),
        const Gap(8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count.toString(),
            style: GoogleFonts.openSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.item, required this.onTap});

  final AdminVerificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
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
              children: [
                _StatusDot(status: item.status),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _prettyDocType(item.docType),
                        style: GoogleFonts.openSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.text1,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        'trade ${item.tradeId.substring(0, 8)}… '
                        '· submitted ${_fmt(item.submittedAt)}'
                        '${item.state == null ? '' : ' · ${item.state}'}'
                        '${item.documentNumber == null ? '' : ' · #${item.documentNumber}'}',
                        style: GoogleFonts.openSans(
                          fontSize: 12,
                          color: c.text2,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  item.status.toUpperCase(),
                  style: GoogleFonts.openSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: _statusColor(context, item.status),
                  ),
                ),
                const Gap(12),
                Icon(Icons.chevron_right, color: c.text3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _prettyDocType(String dbValue) => switch (dbValue) {
    'trade_licence' => 'Trade Licence',
    'abn_certificate' => 'ABN Certificate',
    'public_liability' => 'Public Liability',
    'workers_compensation' => 'Workers Compensation',
    'white_card' => 'White Card',
    'photo_id' => 'Photo ID',
    _ => dbValue,
  };

  static String _fmt(DateTime t) => DateFormat('d MMM yyyy · HH:mm').format(t);

  static Color _statusColor(BuildContext context, String status) {
    final c = context.c;
    return switch (status) {
      'pending' => c.action,
      'approved' => c.verified,
      'rejected' => c.urgent,
      'expired' => c.text3,
      _ => c.text3,
    };
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = switch (status) {
      'pending' => c.action,
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

class _EmptyBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: c.text3),
          const Gap(12),
          Text(
            'No verification documents yet.',
            style: GoogleFonts.openSans(fontSize: 14, color: c.text2),
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Text(
        'Couldn\'t load the queue.\n$error',
        textAlign: TextAlign.center,
        style: GoogleFonts.openSans(fontSize: 13, color: c.urgent),
      ),
    );
  }
}
