import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/breakpoints.dart';
import '../../../../../core/design/colors.dart';
import '../widgets/site_section_frame.dart';

/// "Three things we won't do.": a single dense row of three short
/// value-props. Each block is a bold one-liner + a one-sentence
/// qualifier. The whole strip reads as the inside cover of a
/// job-site clipboard, not a feature grid.
///
/// No section header above it. The strip is its own statement.
class ValuesStrip extends StatelessWidget {
  const ValuesStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final w = MediaQuery.sizeOf(context).width;
    final stacked = w < Bp.laptop;

    const items = [
      _Value(
        label: r'Free for tradies.',
        body:
            'Tradies download, browse, and apply for jobs free, forever. '
            'No subscription. No premium tier. No cut of your pay.',
      ),
      _Value(
        label: r'Builders: $10 a week.',
        body:
            'One flat weekly fee covers every job you post, every applicant '
            'you message, and every licence check. Cancel any time.',
      ),
      _Value(
        label: 'No anonymous operators.',
        body:
            'Every account is checked at sign-up. Anonymous profiles '
            'do not exist on Jobdun.',
      ),
    ];

    return Container(
      width: double.infinity,
      color: c.background,
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: SiteSectionFrame(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cross = stacked ? 1 : 3;
            return Wrap(
              spacing: 32,
              runSpacing: 32,
              children: items
                  .map(
                    (it) => SizedBox(
                      width: stacked
                          ? double.infinity
                          : (constraints.maxWidth - 32 * (cross - 1)) / cross,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Short orange tick; sits above the label
                          // and reads as a "yes, this" affirmation.
                          Container(width: 28, height: 3, color: c.action),
                          const Gap(16),
                          Text(
                            it.label,
                            style: tt.titleLarge!.copyWith(
                              color: c.text1,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const Gap(4),
                          Text(
                            it.body,
                            style: tt.bodyMedium!.copyWith(
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

class _Value {
  const _Value({required this.label, required this.body});
  final String label;
  final String body;
}
