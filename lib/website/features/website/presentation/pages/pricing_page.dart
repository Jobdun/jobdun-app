import 'package:flutter/material.dart';

import '../sections/bottom_cta_section.dart';
import '../sections/comparison_section.dart';
import '../sections/faq_section.dart';
import '../widgets/animated_cta.dart';
import '../widgets/page_hero.dart';
import '../widgets/site_shell.dart';

/// `/pricing` — the whole pitch on one page: it's free, and here's the proof
/// next to what every other platform charges. Leads with the headline, then
/// the side-by-side comparison and the cost-related FAQs.
class PricingPage extends StatelessWidget {
  const PricingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SiteShell(
      slivers: [
        SliverToBoxAdapter(
          child: PageHero(
            eyebrow: 'Pricing',
            title: "It's free.\nHere's the catch: there isn't one.",
            subtitle:
                'No subscription. No price per lead. No cut of the job. We '
                "don't charge builders or trades a cent to connect — and we "
                'never will. Scroll down for exactly how that compares.',
            ctas: [AnimatedCta(label: 'GET STARTED', route: '/contact')],
          ),
        ),
        SliverToBoxAdapter(child: ComparisonSection()),
        SliverToBoxAdapter(child: FaqSection()),
        SliverToBoxAdapter(child: BottomCtaSection()),
      ],
    );
  }
}
