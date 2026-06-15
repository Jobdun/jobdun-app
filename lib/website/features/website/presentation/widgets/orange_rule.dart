import 'package:flutter/material.dart';

import '../../../../../../core/design/colors.dart';

/// A 4-px orange rule used as a section divider in place of empty
/// vertical space. Reads as a "section cut" / heavy underline —
/// the visual equivalent of a band-saw mark on a board.
///
/// Anti-pattern check: this is a *horizontal* line, not a side
/// stripe. The design system bans `border-left` / `border-right`
/// accents on cards; a centred horizontal rule between sections
/// reads as a structural beat, not a decoration.
class OrangeRule extends StatelessWidget {
  const OrangeRule({super.key, this.thickness = 4, this.width = 64});

  final double thickness;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: width,
      height: thickness,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.action,
          borderRadius: BorderRadius.circular(thickness / 2),
        ),
      ),
    );
  }
}
