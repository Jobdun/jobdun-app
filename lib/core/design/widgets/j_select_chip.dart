import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../app/theme/app_colors.dart';

/// Pill-shaped selectable chip from the Figma **Homepage** section
/// (`JobDun-Screens` node 64:2088) — the trade picker on Post a Job 1/2, the
/// "Price per" picker on 2/2, and the read-only trade/price pills on Job
/// Details.
///
/// **Why not [GvChip].** `GvChip` is the *filter* pill on the jobs feed: 6dp
/// radius, solid-orange when active, `.toUpperCase()` labels. This one is
/// drawn from the new foundation — fully round, a tinted fill with an orange
/// hairline when selected, and sentence case. Two different vocabularies for
/// two different jobs; the jobs feed keeps its own until it is redrawn.
///
/// **Contrast.** The mock labels the selected chip `text/action` `#FC5101`,
/// which is 3.34:1 on the tint — below the 4.5:1 bar for 12px text. This uses
/// `c.actionInk` (4.92:1) instead, matching the FTUE rebuild's deviation.
///
/// The chip paints at 32dp to match the mock but claims a 48dp hit box, per
/// MASTER's touch-target floor.
class JSelectChip extends StatelessWidget {
  const JSelectChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;

  /// Null renders a read-only pill (Job Details' trade + price chips), which
  /// drops the button semantics so screen readers don't offer a dead tap.
  final VoidCallback? onTap;

  /// Optional leading glyph — the `$` on Job Details' price pill.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final fg = selected ? c.actionInk : c.text2;

    final pill = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.ease,
      height: 32.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      // No `alignment:` — a Container WITH an alignment expands to fill its
      // parent's bounded constraints, which stretched every chip to the full
      // row width. The inner Row's `MainAxisSize.min` is what sizes the pill
      // to its label.
      decoration: BoxDecoration(
        color: selected ? c.actionBg : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.btn.r),
        border: Border.all(color: selected ? c.action : c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.r, color: fg),
            SizedBox(width: 4.w),
          ],
          Text(
            label,
            style: tt.labelMedium!.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: fg,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return Semantics(label: label, child: pill);

    return Semantics(
      button: true,
      selected: selected,
      label: '$label, ${selected ? "selected" : "not selected"}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        // 8dp of padding above and below the 32dp pill gives the mock's paint
        // size a 48dp touch target. Padding rather than a fixed-height
        // SizedBox on purpose: a SizedBox with only a height set takes the
        // parent's FULL width inside a Wrap, which put every chip on its own
        // line instead of flowing them.
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: pill,
        ),
      ),
    );
  }
}
