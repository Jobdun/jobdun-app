import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/breakpoints.dart';
import '../../../../../core/design/colors.dart';
import '../widgets/reveal_on_scroll.dart';
import '../widgets/site_section_frame.dart';

/// "What 'verified' actually means." — turns the repeated verification claim
/// into proof. Every platform uses the word; this section spells out the exact
/// checks that happen before anyone can pick up a job, so the promise is
/// auditable rather than aspirational.
///
/// Presented as a hairline-divided spec list — the claim leads each row, no
/// decorative per-row icon.
class TrustSafetySection extends StatelessWidget {
  const TrustSafetySection({super.key});

  static const _checks = <_Check>[
    _Check(
      title: 'Licence cross-checked',
      body:
          'The trade registers a licence number and we look it up against '
          'the national register before they can apply for anything.',
    ),
    _Check(
      title: 'Current ABN',
      body:
          'Every builder and business carries an ABN that is checked at '
          'sign-up — not just typed into a box.',
    ),
    _Check(
      title: 'Identity confirmed',
      body:
          'Real names, real people. Identity is verified so anonymous '
          'operators never make it onto the roster.',
    ),
    _Check(
      title: 'Insurance on file',
      body:
          'Public liability and the cover relevant to the trade are '
          'recorded against the profile.',
    ),
    _Check(
      title: 'Reviews from real jobs',
      body:
          'Ratings come only from work actually completed through Jobdun — '
          'never anonymous drive-by reviews.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= Bp.laptop;

    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            "What “verified”\nactually means.",
            style: tt.headlineLarge!.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const Gap(16),
        Text(
          'Every platform uses the word. Here is exactly what it means on '
          'Jobdun — checked before anyone picks up a single job.',
          style: tt.bodyLarge!.copyWith(color: c.text2, height: 1.55),
        ),
      ],
    );

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _checks.length; i++)
          RevealOnScroll(
            delayMs: i * 70,
            child: _CheckRow(check: _checks[i]),
          ),
      ],
    );

    return Container(
      width: double.infinity,
      color: c.surface,
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: SiteSectionFrame(
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: intro),
                  const Gap(56),
                  Expanded(flex: 6, child: list),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [intro, const Gap(40), list],
              ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});

  final _Check check;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: c.border),
        const Gap(20),
        Text(
          check.title,
          style: tt.titleMedium!.copyWith(
            color: c.text1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(6),
        Text(
          check.body,
          style: tt.bodyMedium!.copyWith(color: c.text2, height: 1.5),
        ),
        const Gap(24),
      ],
    );
  }
}

class _Check {
  const _Check({required this.title, required this.body});
  final String title;
  final String body;
}
