import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/design/widgets/j_button.dart';
import '../../../../app/placeholders/admin_status_tag.dart';
import '../providers/admin_user_detail_provider.dart';

/// Moderation surface (#21a) — current account state + Suspend / Ban /
/// Reactivate. Each action calls the audited `admin_set_user_status` RPC and
/// refreshes the detail; the offered actions depend on the current status.
class AdminUserModerationCard extends ConsumerStatefulWidget {
  const AdminUserModerationCard({
    super.key,
    required this.userId,
    required this.status,
  });

  final String userId;
  final String status; // active | suspended | banned

  @override
  ConsumerState<AdminUserModerationCard> createState() =>
      _AdminUserModerationCardState();
}

class _AdminUserModerationCardState
    extends ConsumerState<AdminUserModerationCard> {
  bool _busy = false;

  Future<void> _set(String status) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final res = await ref
        .read(adminModerationProvider)
        .setUserStatus(userId: widget.userId, status: status);
    if (!mounted) return;
    setState(() => _busy = false);
    res.fold(
      (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
      (_) => messenger.showSnackBar(
        SnackBar(content: Text('Account set to ${status.toUpperCase()}.')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final status = widget.status;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MODERATION', style: AdminText.cardLabel(c.text3)),
          const Gap(12),
          AdminStatusTag(
            label: 'Account: ${status.toUpperCase()}',
            tooltip: 'Current moderation status (admin_set_user_status)',
          ),
          const Gap(16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (status != 'active')
                SizedBox(
                  width: 150,
                  child: JButton(
                    label: 'REACTIVATE',
                    onPressed: _busy ? null : () => _set('active'),
                  ),
                ),
              if (status != 'suspended')
                SizedBox(
                  width: 150,
                  child: JButton(
                    label: 'SUSPEND',
                    variant: JButtonVariant.secondary,
                    onPressed: _busy ? null : () => _set('suspended'),
                  ),
                ),
              if (status != 'banned')
                SizedBox(
                  width: 150,
                  child: JButton(
                    label: 'BAN',
                    variant: JButtonVariant.danger,
                    onPressed: _busy ? null : () => _set('banned'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
