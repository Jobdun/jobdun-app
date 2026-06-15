import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/theme/app_icons.dart';
import '../widgets/hover_lift_card.dart';
import '../widgets/reveal_on_scroll.dart';
import '../widgets/site_section_frame.dart';

/// Social proof — three quotes from each side of the marketplace. Cards lift
/// gently on hover (the one card-depth the refined-flat+ direction allows).
///
/// Quotes are indicative placeholders the client swaps for real, consented
/// testimonials — kept in AU voice and tagged by trade + state.
class TestimonialsSection extends StatelessWidget {
  const TestimonialsSection({super.key});

  static const _quotes = <_Quote>[
    _Quote(
      body:
          'Found a verified sparky in two days. No tyre-kickers, '
          'no chasing dead numbers.',
      name: 'Jess M.',
      role: 'Builder · NSW',
    ),
    _Quote(
      body:
          "Every job on here is real. I'm not burning fuel driving to "
          'leads that go nowhere anymore.',
      name: 'Dan R.',
      role: 'Electrician · VIC',
    ),
    _Quote(
      body:
          'Posted a framing job on Friday, had three licensed chippies '
          'lined up by Monday.',
      name: 'Priya S.',
      role: 'Site Manager · QLD',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final w = MediaQuery.sizeOf(context).width;
    final stacked = w < 900;

    return Container(
      width: double.infinity,
      color: c.surface,
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: SiteSectionFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RevealOnScroll(
              child: Semantics(
                header: true,
                child: Text(
                  'Trusted on site.',
                  style: tt.headlineLarge!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),
            const Gap(32),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 24.0;
                final cols = stacked ? 1 : 3;
                final cardWidth =
                    (constraints.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var i = 0; i < _quotes.length; i++)
                      SizedBox(
                        width: stacked ? double.infinity : cardWidth,
                        child: RevealOnScroll(
                          delayMs: i * 90,
                          child: _TestimonialCard(quote: _quotes[i]),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.quote});

  final _Quote quote;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return HoverLiftCard(
      backgroundColor: c.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (var s = 0; s < 5; s++)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(AppIcons.starFilled, size: 16, color: c.star),
                ),
            ],
          ),
          const Gap(16),
          Text(
            '"${quote.body}"',
            style: tt.bodyLarge!.copyWith(color: c.text1, height: 1.55),
          ),
          const Gap(20),
          Text(
            quote.name,
            style: tt.titleSmall!.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(2),
          Text(
            quote.role,
            style: tt.labelMedium!.copyWith(color: c.text2, letterSpacing: 0.6),
          ),
        ],
      ),
    );
  }
}

class _Quote {
  const _Quote({required this.body, required this.name, required this.role});
  final String body;
  final String name;
  final String role;
}
