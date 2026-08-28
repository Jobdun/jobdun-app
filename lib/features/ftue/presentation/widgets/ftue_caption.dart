import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import 'ftue_page_indicator.dart';

/// The two-tone headline that sits on the hero's bottom scrim, with the
/// progress bars underneath.
///
/// Figma `JobDun-Screens` → Onboard (node 50:9942) sets the whole claim in
/// Archivo Black 32/1.2 caps and splits it across two colours: the setup line
/// in ink, the payoff in orange. [lead] gets a hard line break after it;
/// [accent] wraps on its own, which is what produces the three-line stack on
/// slides 1 and 2 and the two-line stack on slide 3.
///
/// The orange is `c.actionInk`, not `c.action` — the mock's bright #FD7434 is
/// only 2.8:1 on the light ground. `actionInk` is the token that exists for
/// exactly this job (orange as *text*) and holds contrast in both themes.
class FtueCaption extends StatelessWidget {
  const FtueCaption({
    super.key,
    required this.lead,
    required this.accent,
    required this.controller,
    required this.slideCount,
  });

  final String lead;
  final String accent;
  final PageController controller;
  final int slideCount;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final headline = Theme.of(
      context,
    ).textTheme.headlineLarge!.copyWith(height: 1.2);

    return Padding(
      padding: EdgeInsets.all(AppSpacing.md.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(lead, style: headline.copyWith(color: c.text1)),
          Text(accent, style: headline.copyWith(color: c.actionInk)),
          Gap(AppSpacing.md.h),
          FtuePageIndicator(controller: controller, count: slideCount),
        ],
      ),
    );
  }
}
