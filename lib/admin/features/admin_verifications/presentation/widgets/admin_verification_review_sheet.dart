import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/design/widgets/j_button.dart';
import '../../data/state_licence_registers.dart';
import '../../data/verification_kind.dart';
import '../providers/admin_verifications_provider.dart';
import 'admin_captured_details_card.dart';
import 'admin_confirm_fields.dart';
import 'admin_official_register_link.dart';
import 'admin_revoke_action.dart';
import 'admin_verification_doc_viewer.dart';

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
  // Admin-confirmed identifier + trade class — what the reviewer actually read
  // off the document image. Pre-filled from the user-typed values so the common
  // "it matches" case is one tap, but editable so a typo doesn't get trusted
  // blindly (audit A2/A3).
  final _confirmedNumberController = TextEditingController();
  final _tradeClassController = TextEditingController();
  // Which decision is in flight ('approved' / 'rejected'), or null when idle.
  // Drives the per-button spinner so the reviewer sees exactly which action
  // is running instead of a single shared flag.
  String? _decidingStatus;
  String? _error;

  bool get _busy => _decidingStatus != null;

  bool get _isTradeLicence => widget.item.docType == 'trade_licence';

  @override
  void initState() {
    super.initState();
    if (widget.item.reviewNotes != null) {
      _notesController.text = widget.item.reviewNotes!;
    }
    if (widget.item.documentNumber != null) {
      _confirmedNumberController.text = widget.item.documentNumber!;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _confirmedNumberController.dispose();
    _tradeClassController.dispose();
    super.dispose();
  }

  Future<void> _decide(String status) async {
    setState(() {
      _decidingStatus = status;
      _error = null;
    });
    try {
      await ref
          .read(adminVerificationsProvider.notifier)
          .setStatus(
            id: widget.item.id,
            status: status,
            notes: _notesController.text,
            // Only meaningful on approve; the provider drops these on reject.
            confirmedNumber: _confirmedNumberController.text,
            tradeClass: _isTradeLicence ? _tradeClassController.text : null,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _decidingStatus = null;
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
                          style: AdminText.dialogTitle(c.text1),
                        ),
                        const Gap(4),
                        Row(
                          children: [
                            Text(
                              i.displayName,
                              style: AdminText.bodyStrong(
                                c.text1,
                              ).copyWith(fontWeight: FontWeight.w700),
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
                                style: AdminText.eyebrow(
                                  c.text3,
                                ).copyWith(letterSpacing: 0.8),
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
                style: AdminText.meta(c.text2),
              ),
              const Gap(16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AdminVerificationDocViewer(filePath: i.filePath),
                      const Gap(16),
                      _MetaTable(item: i),
                      // Trade licence: one-click link to the correct state
                      // register so the admin can confirm the licence on the
                      // official source. Only shows when the state is known.
                      if (i.docType == 'trade_licence' &&
                          licenceRegisterFor(i.state) != null) ...[
                        const Gap(16),
                        AdminOfficialRegisterLink(
                          state: i.state,
                          licenceNumber: i.documentNumber,
                        ),
                      ],
                      if (i.verificationId != null) ...[
                        const Gap(16),
                        AdminCapturedDetailsCard(item: i),
                      ],
                      if (i.lastVerificationFailureReason != null) ...[
                        const Gap(16),
                        _RegulatorFailureBlock(
                          status: i.lastVerificationStatus,
                          detail: i.lastVerificationFailureReason!,
                        ),
                      ],
                      const Gap(16),
                      AdminConfirmFields(
                        numberController: _confirmedNumberController,
                        tradeClassController: _tradeClassController,
                        showTradeClass: _isTradeLicence,
                      ),
                      const Gap(16),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        style: AdminText.value(c.text1),
                        decoration: const InputDecoration(
                          labelText: 'Review notes (optional)',
                        ),
                      ),
                      if (canRevokeVerification(
                        docType: i.docType,
                        lastVerificationStatus: i.lastVerificationStatus,
                      )) ...[
                        const Gap(20),
                        AdminRevokeAction(
                          item: i,
                          onDone: () {
                            if (mounted) Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const Gap(8),
                Text(_error!, style: AdminText.meta(c.urgent)),
              ],
              const Gap(12),
              Row(
                children: [
                  if (!pending)
                    Expanded(
                      child: Text(
                        'Already ${i.status} — changes will overwrite.',
                        style: AdminText.meta(c.text3),
                      ),
                    ),
                  if (pending) const Spacer(),
                  SizedBox(
                    width: 132,
                    child: JButton(
                      label: 'REJECT',
                      variant: JButtonVariant.danger,
                      size: JButtonSize.compact,
                      isLoading: _decidingStatus == 'rejected',
                      onPressed: _busy ? null : () => _decide('rejected'),
                    ),
                  ),
                  const Gap(12),
                  SizedBox(
                    width: 132,
                    child: JButton(
                      label: 'APPROVE',
                      size: JButtonSize.compact,
                      isLoading: _decidingStatus == 'approved',
                      onPressed: _busy ? null : () => _decide('approved'),
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
                style: AdminText.caption(
                  c.urgent,
                ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
              ),
              if (status != null) ...[
                const Gap(8),
                Text(
                  '· ${status!.toUpperCase()}',
                  style: AdminText.caption(c.text3),
                ),
              ],
            ],
          ),
          const Gap(6),
          Text(detail, style: AdminText.value(c.text1).copyWith(height: 1.4)),
          const Gap(4),
          Text(
            'The user fell back to manual upload after this regulator '
            'response. Approve only if the document independently confirms '
            'the claim.',
            style: AdminText.caption(
              c.text3,
            ).copyWith(fontStyle: FontStyle.italic),
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
                    child: Text(r.key, style: AdminText.meta(c.text3)),
                  ),
                  Expanded(
                    child: Text(r.value!, style: AdminText.bodyStrong(c.text1)),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
