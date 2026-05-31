import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';

/// Shared admin empty state — icon + label + optional hint, centred. Gives the
/// "nothing here" surfaces a consistent shape instead of the bare one-line
/// `Text` blocks the list pages used to scatter.
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.label,
    this.hint,
  });

  final IconData icon;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: c.text3),
          const Gap(12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AdminText.body(c.text2),
          ),
          if (hint != null) ...[
            const Gap(4),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: AdminText.meta(c.text3),
            ),
          ],
        ],
      ),
    );
  }
}
