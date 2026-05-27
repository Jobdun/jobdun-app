import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../providers/admin_verifications_provider.dart';

/// Document review dialog. Renders the image via a 60s signed URL, the
/// claim metadata (state/issuer/number/dates), and exposes Approve / Reject
/// buttons that write back to verification_documents through the admin RLS
/// UPDATE policy.
class AdminVerificationReviewSheet extends ConsumerStatefulWidget {
  const AdminVerificationReviewSheet({super.key, required this.item});

  final AdminVerificationItem item;

  @override
  ConsumerState<AdminVerificationReviewSheet> createState() =>
      _AdminVerificationReviewSheetState();
}

class _AdminVerificationReviewSheetState
    extends ConsumerState<AdminVerificationReviewSheet> {
  final _notesController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.item.reviewNotes != null) {
      _notesController.text = widget.item.reviewNotes!;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _decide(String status) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(adminVerificationsProvider.notifier)
          .setStatus(
            id: widget.item.id,
            status: status,
            notes: _notesController.text,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final i = widget.item;
    final pending = i.status == 'pending';
    return Dialog(
      backgroundColor: c.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _prettyDocType(i.docType),
                          style: GoogleFonts.oswald(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: c.text1,
                          ),
                        ),
                        const Gap(4),
                        Row(
                          children: [
                            Text(
                              i.displayName,
                              style: GoogleFonts.openSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: c.text1,
                              ),
                            ),
                            const Gap(8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: c.background,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                'ROLE: ${i.roleLabel}',
                                style: GoogleFonts.openSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: c.text3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Gap(4),
              Text(
                'user ${i.tradeId} · submitted ${_fmt(i.submittedAt)}',
                style: GoogleFonts.openSans(fontSize: 12, color: c.text2),
              ),
              const Gap(16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ImageBlock(filePath: i.filePath),
                      const Gap(16),
                      _MetaTable(item: i),
                      if (i.lastVerificationFailureReason != null) ...[
                        const Gap(16),
                        _RegulatorFailureBlock(
                          status: i.lastVerificationStatus,
                          detail: i.lastVerificationFailureReason!,
                        ),
                      ],
                      const Gap(16),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Review notes (optional)',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: c.background,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const Gap(8),
                Text(
                  _error!,
                  style: GoogleFonts.openSans(fontSize: 12, color: c.urgent),
                ),
              ],
              const Gap(12),
              Row(
                children: [
                  if (!pending)
                    Text(
                      'Already ${i.status} — changes will overwrite.',
                      style: GoogleFonts.openSans(fontSize: 12, color: c.text3),
                    ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: _saving ? null : () => _decide('rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.urgent,
                      side: BorderSide(color: c.urgent),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text('REJECT'),
                    ),
                  ),
                  const Gap(12),
                  FilledButton(
                    onPressed: _saving ? null : () => _decide('approved'),
                    style: FilledButton.styleFrom(backgroundColor: c.action),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text('APPROVE'),
                    ),
                  ),
                ],
              ),
            ],
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
}

class _ImageBlock extends ConsumerWidget {
  const _ImageBlock({required this.filePath});
  final String filePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return FutureBuilder<String>(
      future: ref.read(adminVerificationsProvider.notifier).signedUrl(filePath),
      builder: (context, snap) {
        if (!snap.hasData && !snap.hasError) {
          return Container(
            height: 280,
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Container(
            height: 120,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'Couldn\'t load file:\n${snap.error}',
                textAlign: TextAlign.center,
                style: GoogleFonts.openSans(fontSize: 12, color: c.urgent),
              ),
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            snap.data!,
            height: 320,
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Container(
              height: 120,
              alignment: Alignment.center,
              color: c.background,
              child: Text(
                'File is not a viewable image. Open the URL directly:\n${snap.data}',
                style: GoogleFonts.openSans(fontSize: 11, color: c.text2),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RegulatorFailureBlock extends StatelessWidget {
  const _RegulatorFailureBlock({required this.status, required this.detail});

  final String? status;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.urgent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.urgent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: c.urgent, size: 16),
              const Gap(6),
              Text(
                'WHAT THE REGULATOR SAID',
                style: GoogleFonts.openSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: c.urgent,
                ),
              ),
              if (status != null) ...[
                const Gap(8),
                Text(
                  '· ${status!.toUpperCase()}',
                  style: GoogleFonts.openSans(fontSize: 11, color: c.text3),
                ),
              ],
            ],
          ),
          const Gap(6),
          Text(
            detail,
            style: GoogleFonts.openSans(
              fontSize: 13,
              color: c.text1,
              height: 1.4,
            ),
          ),
          const Gap(4),
          Text(
            'The user fell back to manual upload after this regulator '
            'response. Approve only if the document independently confirms '
            'the claim.',
            style: GoogleFonts.openSans(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: c.text3,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaTable extends StatelessWidget {
  const _MetaTable({required this.item});
  final AdminVerificationItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rows = <MapEntry<String, String?>>[
      MapEntry('State', item.state),
      MapEntry('Issuer', item.issuer),
      MapEntry('Document number', item.documentNumber),
      MapEntry(
        'Issued',
        item.issuedDate == null
            ? null
            : DateFormat('d MMM yyyy').format(item.issuedDate!),
      ),
      MapEntry(
        'Expires',
        item.expiryDate == null
            ? null
            : DateFormat('d MMM yyyy').format(item.expiryDate!),
      ),
      MapEntry(
        'Last reviewed',
        item.reviewedAt == null
            ? null
            : '${DateFormat('d MMM yyyy · HH:mm').format(item.reviewedAt!)} by ${item.reviewedBy?.substring(0, 8) ?? 'unknown'}…',
      ),
    ];
    final visible = rows.where((r) => r.value != null).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: visible
          .map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      r.key,
                      style: GoogleFonts.openSans(fontSize: 12, color: c.text3),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r.value!,
                      style: GoogleFonts.openSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.text1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
