import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';

/// One site ticket, in one of two trust tiers.
///
/// Verified means a human reviewed an uploaded document. Self-declared means
/// the user ticked a box. These MUST stay visually distinct: collapsing them
/// would let a claim read as a checked credential, which is the single thing
/// the trust layer exists to prevent, and a builder acting on it is making a
/// site-safety decision.
///
/// The tiers differ by GLYPH and by SEMANTICS LABEL, not by colour alone
/// (MASTER: "never colour alone to convey state"). A colour-blind user or a
/// screen-reader user gets the same information as everyone else.
class TicketChip extends StatelessWidget {
  const TicketChip({super.key, required this.label, required this.isVerified});

  final String label;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    // Verified sits on the green tinted pair. Self-declared sits on
    // surfaceRaised, which carries text1 ONLY — text2/text3 fall to 4.04:1 and
    // 3.54:1 there, both under the 4.5 body floor (app_colors.dart:105,110).
    final bg = isVerified ? c.verifiedBg : c.surfaceRaised;
    final fg = isVerified ? c.verifiedTx : c.text1;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$label, ${isVerified ? 'verified' : 'self-declared'}',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.chip.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              // sealCheck vs an empty circle — legible as different shapes at
              // 16px, which is the point.
              isVerified ? AppIcons.verified : AppIcons.radioOff,
              size: AppIconSize.micro.r,
              color: fg,
            ),
            Gap(6.w),
            Flexible(
              child: Text(
                label.toUpperCase(),
                style: tt.labelMedium!.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
