import 'package:flutter/material.dart';

import '../sections/bottom_cta_section.dart';
import '../sections/comparison_section.dart';
import '../sections/features_section.dart';
import '../sections/testimonials_section.dart';
import '../sections/trade_categories_section.dart';
import '../widgets/animated_cta.dart';
import '../widgets/page_hero.dart';
import '../widgets/site_shell.dart';

/// `/for-crews` — the find-work side. Leads with local, real, paid-in-full
/// work, makes the "always free for tradies" promise explicit, then reuses
/// features, comparison, trade chips and proof framed for a trade deciding
/// whether to sign up.
class ForCrewsPage extends StatelessWidget {
  const ForCrewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SiteShell(
      slivers: [
        SliverToBoxAdapter(
          child: PageHero(
            eyebrow: 'For crews & trades',
            title: 'Real work, close to home.\nAnd you keep all of it.',
            subtitle:
                'See the jobs that are actually drivable from your yard, quote '
                'on your own terms, and talk to the builder direct. Jobdun '
                'is free for tradies — to download, to apply, to get paid. '
                'Always.',
            ctas: [
              AnimatedCta(label: 'FIND WORK NEAR YOU', route: '/contact'),
              AnimatedCta(
                label: 'See the pricing',
                route: '/pricing',
                filled: false,
                icon: null,
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(child: FeaturesSection()),
        SliverToBoxAdapter(child: ComparisonSection()),
        SliverToBoxAdapter(child: TradeCategoriesSection()),
        SliverToBoxAdapter(child: TestimonialsSection()),
        SliverToBoxAdapter(child: BottomCtaSection()),
      ],
    );
  }
}
