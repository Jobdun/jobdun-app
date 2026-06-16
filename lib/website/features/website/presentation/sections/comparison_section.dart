import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/theme/app_icons.dart';
import '../widgets/reveal_on_scroll.dart';
import '../widgets/site_section_frame.dart';

/// "What you keep, that other platforms take." — the competitive wedge.
///
/// Every major AU trades platform charges the tradie: a subscription, a price
/// per lead, or a cut of the job. Jobdun charges neither side to connect. This
/// section proves the "no fees" line the features grid makes, as a side-by-side
/// the reader can scan in five seconds. No competitor is named — the right-hand
/// column is the honest category, "lead-buying platforms".
class ComparisonSection extends StatelessWidget {
  const ComparisonSection({super.key});

  // Parallel rows — index i of [_jobdun] answers index i of [_others].
  static const _jobdun = <String>[
    'Free to post a job and free to apply',
    'No subscription — not now, not ever',
    'You keep 100% of what the job pays',
    'A job you apply for is yours alone',
    'Message the builder or trade direct',
    'Licence + ABN checked before contact',
  ];
  static const _others = <String>[
    r'Pay $30–80+ for every single lead',
    r'$200–600 a month just to stay listed',
    'Up to ~15% skimmed off the job',
    'The same lead is sold to 3+ rivals',
    'Routed through a lead broker first',
    'Verification varies — if it happens',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= 820;

    final jobdun = _CompareCard(
      title: 'Jobdun',
      tagline: 'What you pay to connect: nothing.',
      items: _jobdun,
      positive: true,
      highlighted: true,
    );
    final others = _CompareCard(
      title: 'Lead-buying platforms',
      tagline: 'What you pay to be found: plenty.',
      items: _others,
      positive: false,
      highlighted: false,
    );

    return Container(
      width: double.infinity,
      color: c.surface,
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: SiteSectionFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RevealOnScroll(
              child: Semantics(
                header: true,
                child: Text(
                  'What you keep, that other platforms take.',
                  style: tt.headlineLarge!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            const Gap(12),
            RevealOnScroll(
              delayMs: 60,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Text(
                  'Most platforms charge tradies to be found — a monthly fee, a '
                  'price per lead, or a cut of the job. We charge neither side a '
                  'cent to connect.',
                  style: tt.bodyLarge!.copyWith(color: c.text2, height: 1.55),
                ),
              ),
            ),
            const Gap(40),
            RevealOnScroll(
              delayMs: 120,
              child: wide
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: jobdun),
                          const Gap(20),
                          Expanded(child: others),
                        ],
                      ),
                    )
                  : Column(children: [jobdun, const Gap(20), others]),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({
    required this.title,
    required this.tagline,
    required this.items,
    required this.positive,
    required this.highlighted,
  });

  final String title;
  final String tagline;
  final List<String> items;
  final bool positive;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final icon = positive ? AppIcons.check : AppIcons.close;
    final iconColor = positive ? c.verified : c.text3;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: highlighted ? c.action : c.border,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: tt.titleLarge!.copyWith(
              color: highlighted ? c.actionInk : c.text1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(4),
          Text(tagline, style: tt.bodyMedium!.copyWith(color: c.text2)),
          const Gap(20),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: iconColor),
                  const Gap(12),
                  Expanded(
                    child: Text(
                      item,
                      style: tt.bodyMedium!.copyWith(
                        color: positive ? c.text1 : c.text2,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
