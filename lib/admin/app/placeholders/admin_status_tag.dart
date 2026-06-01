import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/theme/app_icons.dart';

/// Muted, outline-only tag for admin surfaces that are scaffolded but **not yet
/// wired to data**. Deliberately the visual opposite of the app's *live* status
/// pills — which are solid-filled (`AdminJobListRow._StatusPill`,
/// `AdminUserDetailHeader._StatusPill`, the verification badges). A placeholder
/// is transparent-filled, outlined in `borderStrong`, lettered in the recessive
/// `text3`, and (when [soon]) carries a lock, so it can never be confused for
/// real data in a demo.
///
/// Always pass a [tooltip] naming the phase that lights it up.
class AdminStatusTag extends StatelessWidget {
  const AdminStatusTag({
    super.key,
    required this.label,
    this.icon,
    this.soon = true,
    this.tooltip,
  });

  /// Short all-caps label — 'FREE', 'ACTIVE', or an em-dash '—' for an unknown
  /// count. Pass already-uppercased (matches the live pills).
  final String label;

  /// Optional leading glyph (e.g. [AppIcons.warning] for an open-reports tag).
  final IconData? icon;

  /// Trailing lock — the "not wired yet" affordance. On by default because
  /// every consumer of this widget is, by definition, a placeholder.
  final bool soon;

  /// Hover / long-press copy. Should name the phase, e.g.
  /// 'Open reports — Phase 2 (moderation)'.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c.text3),
            const Gap(4),
          ],
          Text(
            label,
            style: AdminText.eyebrow(c.text3).copyWith(letterSpacing: 1.2),
          ),
          if (soon) ...[
            const Gap(5),
            Icon(AppIcons.lock, size: 11, color: c.text3),
          ],
        ],
      ),
    );

    if (tooltip == null) return tag;
    return Tooltip(message: tooltip!, child: tag);
  }
}
