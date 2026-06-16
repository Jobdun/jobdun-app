import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/theme/app_icons.dart';
import '../widgets/reveal_on_scroll.dart';
import '../widgets/site_section_frame.dart';

/// "What 'verified' actually means." — turns the repeated verification claim
/// into proof. Every platform uses the word; this section spells out the exact
/// checks that happen before anyone can pick up a job, so the promise is
/// auditable rather than aspirational.
class TrustSafetySection extends StatelessWidget {
  const TrustSafetySection({super.key});

  static const _checks = <_Check>[
    _Check(
      icon: AppIcons.verified,
      title: 'Licence cross-checked',
      body:
          'The trade registers a licence number and we look it up against '
          'the national register before they can apply for anything.',
    ),
    _Check(
      icon: AppIcons.building,
      title: 'Current ABN',
      body:
          'Every builder and business carries an ABN that is checked at '
          'sign-up — not just typed into a box.',
    ),
    _Check(
      icon: AppIcons.user,
      title: 'Identity confirmed',
      body:
          'Real names, real people. Identity is verified so anonymous '
          'operators never make it onto the roster.',
    ),
    _Check(
      icon: AppIcons.policy,
      title: 'Insurance on file',
      body:
          'Public liability and the cover relevant to the trade are '
          'recorded against the profile.',
    ),
    _Check(
      icon: AppIcons.star,
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
    final wide = MediaQuery.sizeOf(context).width >= 900;

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
            child: Padding(
              padding: EdgeInsets.only(
                bottom: i == _checks.length - 1 ? 0 : 24,
              ),
              child: _CheckRow(check: _checks[i]),
            ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: c.verifiedBg,
            borderRadius: BorderRadius.circular(AppRadius.btn),
          ),
          child: Icon(check.icon, size: 22, color: c.verified),
        ),
        const Gap(16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                check.title,
                style: tt.titleMedium!.copyWith(
                  color: c.text1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(4),
              Text(
                check.body,
                style: tt.bodyMedium!.copyWith(color: c.text2, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Check {
  const _Check({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
}
