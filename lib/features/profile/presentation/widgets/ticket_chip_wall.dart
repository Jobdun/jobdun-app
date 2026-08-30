import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import 'ticket_chip.dart';

/// The tickets block on a profile.
///
/// Verified chips sort first so the strongest signal is read first; within a
/// tier the order is stable (alphabetical) so the block doesn't reshuffle
/// between builds.
///
/// [showDisclaimer] is true on builder-facing surfaces only. MASTER bans
/// handholding microcopy, and this one line earns the exception: a builder
/// acting on a self-declared ticket is making a site-safety call, not a UI
/// preference. It renders only when there is actually something self-declared
/// to warn about.
class TicketChipWall extends StatelessWidget {
  const TicketChipWall({
    super.key,
    required this.labelsBySlug,
    required this.selectedSlugs,
    required this.verifiedSlugs,
    this.showDisclaimer = false,
  });

  /// slug → short display name, from `site_tickets`. A slug with no entry
  /// falls back to the raw slug rather than vanishing, so a ticket added to
  /// the table after this build shipped still renders.
  final Map<String, String> labelsBySlug;
  final List<String> selectedSlugs;
  final Set<String> verifiedSlugs;
  final bool showDisclaimer;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    final ordered = [...selectedSlugs]
      ..sort((a, b) {
        final av = verifiedSlugs.contains(a) ? 0 : 1;
        final bv = verifiedSlugs.contains(b) ? 0 : 1;
        return av != bv ? av.compareTo(bv) : a.compareTo(b);
      });

    final hasSelfDeclared = ordered.any((s) => !verifiedSlugs.contains(s));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            for (final slug in ordered)
              TicketChip(
                label: labelsBySlug[slug] ?? slug,
                isVerified: verifiedSlugs.contains(slug),
              ),
          ],
        ),
        if (showDisclaimer && hasSelfDeclared) ...[
          Gap(AppSpacing.md.h),
          Text(
            'Grey tickets are self-declared. Sight the card before site '
            'induction.',
            style: tt.bodySmall!.copyWith(color: c.text2),
          ),
        ],
      ],
    );
  }
}
