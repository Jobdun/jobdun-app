import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../../../../app/theme/breakpoints.dart';
import '../widgets/illustrations/badge_seal_illustration.dart';
import '../widgets/illustrations/hammer_mark_illustration.dart';
import '../widgets/illustrations/location_rings_illustration.dart';
import '../widgets/site_section_frame.dart';

/// "How it works": three vector illustrations + a few lines of body
/// copy each. The section deliberately *does not* use the
/// eyebrow / huge headline / paragraph formula. Each block is a
/// vector mark + a bold one-liner + a sentence of body. Reads as a
/// documentation panel, not as a hero.
///
/// On desktop, three columns. On mobile, stacked.
class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final w = MediaQuery.sizeOf(context).width;
    final stacked = w < Bp.laptop;

    const steps = [
      _Step(
        illustrationKind: _StepKind.seal,
        title: 'Verified before they apply.',
        body:
            'Trades register with their licence number. We cross-check '
            'the national register before they can pick up a single job.',
      ),
      _Step(
        illustrationKind: _StepKind.rings,
        title: 'Local by default.',
        body:
            'Pick the suburb you work in. The feed shows you the work '
            "that's actually drivable from your yard, not 80 kilometres of "
            'scroll-and-guess.',
      ),
      _Step(
        illustrationKind: _StepKind.hammer,
        title: 'On the tools in three taps.',
        body:
            'See a job. Check the trust score. Apply. The platform gets '
            'out of the way once the work starts.',
      ),
    ];

    return Container(
      width: double.infinity,
      color: c.surface,
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: SiteSectionFrame(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cross = stacked ? 1 : 3;
            return Wrap(
              spacing: 48,
              runSpacing: 48,
              children: steps
                  .map(
                    (s) => SizedBox(
                      width: stacked
                          ? double.infinity
                          : (constraints.maxWidth - 48 * (cross - 1)) / cross,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          s.illustration(context),
                          Gap(AppSpacing.lg.h),
                          Text(
                            s.title,
                            style: tt.headlineSmall!.copyWith(
                              color: c.text1,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          Gap(AppSpacing.sm.h),
                          Text(
                            s.body,
                            style: tt.bodyLarge!.copyWith(
                              color: c.text2,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}

enum _StepKind { seal, rings, hammer }

class _Step {
  const _Step({
    required this.illustrationKind,
    required this.title,
    required this.body,
  });
  final _StepKind illustrationKind;
  final String title;
  final String body;

  Widget illustration(BuildContext context) {
    return switch (illustrationKind) {
      _StepKind.seal => const BadgeSealIllustration(size: 96),
      _StepKind.rings => const LocationRingsIllustration(size: 96),
      _StepKind.hammer => const HammerMarkIllustration(size: 96),
    };
  }
}
