import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';

/// A small white card that floats over the onboarding hero photo.
///
/// Figma `JobDun-Screens` → Onboard (node 17:5084) uses three sizes of the same
/// object, so they share one widget:
///
/// * [FtueOverlayCard.stacked] — icon above a centred label. Slide 1's
///   "Licensed & Verified" / "ID Checked" trust seals.
/// * [FtueOverlayCard.pin] — 24dp pin beside a label, tighter corners. Slide
///   2's suburb pins.
/// * [FtueOverlayCard.feature] — 40dp glyph beside a two-line label. Slide 3's
///   "Made in Australia" / "For Builders and Crews" / "Built for sites".
///
/// [child] takes precedence over [icon] so a caller can supply an SVG glyph
/// (the Australia outline has no Phosphor equivalent) without a second widget.
class FtueOverlayCard extends StatelessWidget {
  const FtueOverlayCard.stacked({
    super.key,
    required this.label,
    this.icon,
    this.child,
  }) : width = 91,
       padding = 12,
       gap = 8,
       iconSize = 48,
       radius = AppRadius.overlayCard,
       isStacked = true,
       isStrongBorder = false;

  /// Sizes to its label rather than to a fixed width: the suburb names come
  /// from a live IP-geo lookup, so "Kellyville Ridge" has to fit as gracefully
  /// as "Penrith". The mock's fixed 109 wrapped anything past nine characters.
  const FtueOverlayCard.pin({
    super.key,
    required this.label,
    this.icon,
    this.child,
  }) : width = null,
       padding = 8,
       gap = 8,
       iconSize = 24,
       radius = AppRadius.overlayChip,
       isStacked = false,
       isStrongBorder = false;

  const FtueOverlayCard.feature({
    super.key,
    required this.label,
    this.icon,
    this.child,
  }) : width = 156,
       padding = 12,
       gap = 10,
       iconSize = 40,
       radius = AppRadius.overlayCard,
       isStacked = false,
       isStrongBorder = true;

  final String label;

  /// Phosphor glyph, tinted `c.actionInk`. Ignored when [child] is set.
  final IconData? icon;

  /// Pre-built glyph (e.g. an `SvgPicture`) rendered instead of [icon].
  final Widget? child;

  /// Fixed card width, or null to size to the label (capped at [_maxIntrinsicWidth]).
  final double? width;
  final double padding;
  final double gap;
  final double iconSize;
  final double radius;
  final bool isStacked;
  final bool isStrongBorder;

  /// Ceiling for label-sized cards.
  static const _maxIntrinsicWidth = 170.0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    final glyph =
        child ??
        Icon(icon, size: iconSize.r, color: c.actionInk, semanticLabel: '');

    final text = Text(
      label,
      textAlign: isStacked ? TextAlign.center : TextAlign.start,
      style: tt.labelMedium!.copyWith(
        color: c.text1,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        height: 1.2,
      ),
    );

    return Container(
      width: width?.w,
      // Intrinsic cards still need a ceiling so one very long place name can't
      // stretch the chip across the hero.
      constraints: width == null
          ? BoxConstraints(maxWidth: _maxIntrinsicWidth.w)
          : null,
      padding: EdgeInsets.all(padding.r),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(radius.r),
        border: Border.all(color: isStrongBorder ? c.borderStrong : c.border),
        boxShadow: [
          // Figma Elevation/xs. Deliberately a literal black rather than a
          // token: on the dark theme it resolves to invisible, which is the
          // correct outcome — dark surfaces separate by border, not shadow.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isStacked
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [glyph, Gap(gap.h), text],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                glyph,
                Gap(gap.w),
                Flexible(child: text),
              ],
            ),
    );
  }
}
