import 'package:flutter/material.dart';

import '../sections/bottom_cta_section.dart';
import '../sections/comparison_section.dart';
import '../sections/faq_section.dart';
import '../widgets/animated_cta.dart';
import '../widgets/page_hero.dart';
import '../widgets/site_shell.dart';

/// `/pricing` — the whole pitch on one page: free for tradies, $10 a week
/// for builders, and the side-by-side against every other platform that
/// charges per-lead or takes a cut. Leads with the headline, then the
/// comparison and the cost-related FAQs.
class PricingPage extends StatelessWidget {
  const PricingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SiteShell(
      slivers: [
        SliverToBoxAdapter(
          child: PageHero(
            eyebrow: 'Pricing',
            title: 'Free for tradies.\n\$10 a week for builders.',
            subtitle:
                'No price per lead. No cut of the job. Tradies download and '
                'apply free, forever. Builders pay a flat \$10 a week — '
                'cancel any time. Scroll down to see how that lines up '
                'against what every other platform charges.',
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
