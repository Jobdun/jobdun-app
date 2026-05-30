import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../providers/admin_verifications_provider.dart';

/// Admin "Captured details" card — the curated verification projection the
/// admin sees during review (legal name, entity type, GST, register source,
/// business state, as-at). The "VIEW RAW" action is audit-logged: it calls the
/// admin_view_verification_raw RPC, which writes an admin_actions row before
/// returning verification_events.raw_response.
class AdminCapturedDetailsCard extends ConsumerWidget {
  const AdminCapturedDetailsCard({super.key, required this.item});

  final AdminVerificationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final rows = <MapEntry<String, String?>>[
      MapEntry('Legal name', item.capturedLegalName),
      MapEntry('Entity type', item.capturedEntityType),
      MapEntry(
        'GST',
        item.gstRegistered == null
            ? null
            : (item.gstRegistered! ? 'Registered' : 'Not registered'),
      ),
      MapEntry('Register', item.registerSource),
      MapEntry('Business state', item.abrState),
      MapEntry(
        'Captured',
        item.detailCapturedAt == null
            ? null
            : DateFormat('d MMM yyyy · HH:mm').format(item.detailCapturedAt!),
      ),
    ].where((r) => r.value != null).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
              Text(
                'CAPTURED DETAILS',
                style: GoogleFonts.openSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: c.text3,
                ),
              ),
              const Spacer(),
              if (item.verificationId != null)
                TextButton(
                  onPressed: () => _showRaw(context, ref),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(
                    'VIEW RAW',
                    style: GoogleFonts.openSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: c.action,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (rows.isEmpty)
            Text(
              'No structured details captured yet.',
              style: GoogleFonts.openSans(fontSize: 12, color: c.text3),
            )
          else
            ...rows.map((r) => _DetailRow(label: r.key, value: r.value!)),
        ],
      ),
    );
  }

  void _showRaw(BuildContext context, WidgetRef ref) {
    final c = context.c;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          'Raw regulator payload',
          style: GoogleFonts.oswald(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: c.text1,
          ),
        ),
        content: SizedBox(
          width: 560,
          child: FutureBuilder<Map<String, dynamic>?>(
            future: ref
                .read(adminVerificationsProvider.notifier)
                .viewRaw(item.verificationId!),
            builder: (context, snap) {
              if (!snap.hasData && !snap.hasError) {
                return const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Text(
                  'Couldn\'t load raw payload:\n${snap.error}',
                  style: GoogleFonts.openSans(fontSize: 12, color: c.urgent),
                );
              }
              final json = const JsonEncoder.withIndent(
                '  ',
              ).convert(snap.data ?? <String, dynamic>{});
              return SingleChildScrollView(
                child: SelectableText(
                  json,
                  style: GoogleFonts.robotoMono(fontSize: 11, color: c.text2),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.openSans(fontSize: 12, color: c.text3),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.openSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.text1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
