import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/theme/app_icons.dart';

/// A recessive, outline-only metric tile for not-yet-wired admin surfaces: an
/// em-dash value, a lock, and a milestone eyebrow. The placeholder twin of the
/// dashboard's live stat tile — transparent fill + muted `text3` so it can't be
/// mistaken for real data in a client demo. One source of truth for the
/// "coming soon" stat look (dashboard, Reports, Payments).
class AdminPlaceholderStat extends StatelessWidget {
  const AdminPlaceholderStat({
    super.key,
    required this.label,
    required this.phase,
    this.value = '—',
  });

  /// All-caps metric name, e.g. 'OPEN REPORTS'.
  final String label;

  /// Milestone tag shown beneath the value + in the tooltip, e.g. 'M5'.
  final String phase;

  /// Defaults to an em-dash — never an invented number.
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: 'Not wired yet — $phase.',
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: AdminText.eyebrow(c.text3))),
                Icon(AppIcons.lock, size: 12, color: c.text3),
              ],
            ),
            const Gap(10),
            Text(value, style: AdminText.statValue(c.text3)),
            const Gap(4),
            Text(
              phase,
              style: AdminText.caption(
                c.text3,
              ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}
