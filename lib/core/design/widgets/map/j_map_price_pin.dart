import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../colors.dart';

/// Information-bearing map pin (map verdict #2, Zillow/Domain pattern): the
/// pin shows the job's rate / QUOTE / URGENT instead of a generic droplet,
/// so the map answers "worth tapping?" at a glance. Selected pins invert to
/// the filled-orange state and sit above their neighbours.
class JMapPricePin extends StatelessWidget {
  const JMapPricePin({
    super.key,
    required this.label,
    this.selected = false,
    this.urgent = false,
    required this.onTap,
  });

  /// Short pin text ('\$55/hr', 'QUOTE', 'URGENT') — keep ≤ 8 chars; the
  /// pin ellipsizes rather than growing into a banner.
  final String label;

  final bool selected;

  /// Urgent jobs use the urgent pair — a status, not a CTA (caution ≠ brand).
  final bool urgent;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final (Color bg, Color fg, Color border) = selected
        ? (c.action, c.onAction, c.action)
        : urgent
        ? (c.urgentBg, c.urgentTx, c.urgent)
        : (c.surface, c.actionInk, c.action);
    return Semantics(
      label: 'Job pin: $label${selected ? ', selected' : ''}',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: border, width: selected ? 2 : 1.5),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.labelMedium!.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
