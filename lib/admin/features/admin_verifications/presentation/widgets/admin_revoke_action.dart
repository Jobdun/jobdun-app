import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/design/widgets/j_button.dart';
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
              style: AdminText.dialogTitle(c.text1).copyWith(fontSize: 18),
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
                  style: AdminText.value(c.text2).copyWith(height: 1.4),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 2,
                  style: AdminText.input(c.text1),
                  onChanged: (v) =>
                      setLocal(() => canSubmit = v.trim().isNotEmpty),
                  decoration: const InputDecoration(
                    labelText: 'Reason for revoking',
                  ),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: 110,
                child: JButton(
                  label: 'CANCEL',
                  variant: JButtonVariant.secondary,
                  size: JButtonSize.compact,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
              SizedBox(
                width: 120,
                child: JButton(
                  label: 'REVOKE',
                  variant: JButtonVariant.danger,
                  size: JButtonSize.compact,
                  onPressed: canSubmit
                      ? () => Navigator.of(
                          dialogContext,
                        ).pop(controller.text.trim())
                      : null,
                ),
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
          Text(_error!, style: AdminText.meta(c.urgent)),
          const SizedBox(height: 8),
        ],
        JButton(
          label: 'REVOKE VERIFICATION',
          variant: JButtonVariant.danger,
          size: JButtonSize.compact,
          icon: Icons.gpp_bad_outlined,
          isLoading: _busy,
          onPressed: _busy ? null : _revoke,
        ),
        const SizedBox(height: 4),
        Text(
          'User currently holds a verified ${docTypeToVerificationKind(widget.item.docType) ?? ''} '
          'row. Revoking undoes it across the app.',
          style: AdminText.caption(c.text3),
        ),
      ],
    );
  }
}
