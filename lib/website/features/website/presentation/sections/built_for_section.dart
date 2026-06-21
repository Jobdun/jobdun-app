import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../widgets/site_section_frame.dart';

/// A long-form "for the people who actually build" section. Just
/// paragraphs, set in body-large Inter. Reads like a job-site
/// notice on the wall: no widgets, no rules, no cards.
///
/// The whole section is one centred block capped at 720ch so the
/// reading line stays inside the FTUE voice. Pairs as the editorial
/// break between the screenshot-heavy hero and the structured
/// "how it works" panels.
class BuiltForSection extends StatelessWidget {
  const BuiltForSection({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: c.background,
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: SiteSectionFrame(
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We are not a marketplace. We are a roster.',
              style: tt.headlineMedium!.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            Gap(AppSpacing.lg.h),
            Text(
              'Jobdun is a roster of the trades and builders who keep '
              'this country upright. Sparkies. Chippies. Plumbers. '
              'Concreters. Roofers. Brickies. The ones who actually '
              'turn up at six.',
              style: tt.bodyLarge!.copyWith(color: c.text1, height: 1.6),
            ),
            Gap(AppSpacing.md.h),
            Text(
              'Every name on the roster has been checked. Every '
              'licence has been looked up. Every builder has an ABN. '
              "If we wouldn't put them on our own site, they don't "
              'go on yours.',
              style: tt.bodyLarge!.copyWith(color: c.text2, height: 1.6),
            ),
            Gap(AppSpacing.md.h),
            Text(
              'We are a small team. We have used the trades in this '
              "roster ourselves. If you have a job and we don't have a "
              "trade for it, we'll say so. That's the whole pitch.",
              style: tt.bodyLarge!.copyWith(color: c.text2, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
