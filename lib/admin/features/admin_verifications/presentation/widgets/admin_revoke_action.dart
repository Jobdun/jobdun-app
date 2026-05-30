import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../data/verification_kind.dart';
import '../providers/admin_verifications_provider.dart';

/// "Revoke verification" action, shown on the review sheet ONLY when the user
/// currently holds a verified row of this kind (`lastVerificationStatus ==
/// 'verified'` + a revocable doc type). Revoking is destructive — it clears the
/// verified `verifications` row so a wrongly-verified ABN/licence can be undone
/// (audit B4) — so it requires a typed reason and an explicit confirm before
/// calling the `revoke_verification` RPC. On success the host sheet closes.
class AdminRevokeAction extends ConsumerStatefulWidget {
  const AdminRevokeAction({
    super.key,
    required this.item,
    required this.onDone,
  });

  final AdminVerificationItem item;

  /// Called after a successful revoke so the host sheet can pop/refresh.
  final VoidCallback onDone;

  @override
  ConsumerState<AdminRevokeAction> createState() => _AdminRevokeActionState();
}

class _AdminRevokeActionState extends ConsumerState<AdminRevokeAction> {
  bool _busy = false;
  String? _error;

  Future<void> _revoke() async {
    final kind = docTypeToVerificationKind(widget.item.docType);
    if (kind == null) return; // defensive — gate above already guards this.
    final reason = await _promptReason();
    if (reason == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(adminVerificationsProvider.notifier)
          .revoke(userId: widget.item.tradeId, kind: kind, reason: reason);
      if (mounted) widget.onDone();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  /// Confirm dialog that also captures the mandatory revoke reason. Returns the
  /// trimmed reason, or null if the admin cancelled or left it blank.
  Future<String?> _promptReason() {
    final controller = TextEditingController();
    final c = context.c;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        var canSubmit = false;
        return StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            backgroundColor: c.surface,
            title: Text(
              'Revoke verification?',
              style: GoogleFonts.oswald(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.text1,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This clears the user\'s verified status for this '
                  'identity. They will appear unverified across the app '
                  'until they re-verify. Enter a reason — it is recorded in '
                  'the audit log.',
                  style: GoogleFonts.openSans(
                    fontSize: 13,
                    color: c.text2,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 2,
                  onChanged: (v) =>
                      setLocal(() => canSubmit = v.trim().isNotEmpty),
                  decoration: InputDecoration(
                    labelText: 'Reason for revoking',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: c.background,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('CANCEL'),
              ),
              FilledButton(
                onPressed: canSubmit
                    ? () => Navigator.of(
                        dialogContext,
                      ).pop(controller.text.trim())
                    : null,
                style: FilledButton.styleFrom(backgroundColor: c.urgent),
                child: const Text('REVOKE'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          Text(
            _error!,
            style: GoogleFonts.openSans(fontSize: 12, color: c.urgent),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: _busy ? null : _revoke,
          icon: Icon(Icons.gpp_bad_outlined, size: 18, color: c.urgent),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.urgent,
            side: BorderSide(color: c.urgent.withValues(alpha: 0.6)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          label: Text(
            'REVOKE VERIFICATION',
            style: GoogleFonts.oswald(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'User currently holds a verified ${docTypeToVerificationKind(widget.item.docType) ?? ''} '
          'row. Revoking undoes it across the app.',
          style: GoogleFonts.openSans(fontSize: 11, color: c.text3),
        ),
      ],
    );
  }
}
