import 'package:flutter/material.dart';

import '../sections/bottom_cta_section.dart';
import '../sections/comparison_section.dart';
import '../sections/features_section.dart';
import '../sections/testimonials_section.dart';
import '../sections/trust_safety_section.dart';
import '../widgets/animated_cta.dart';
import '../widgets/page_hero.dart';
import '../widgets/site_shell.dart';

/// `/for-builders` — the hiring side. Leads with the chase-free promise, then
/// reuses the trust, features, comparison and proof sections framed for a
/// builder deciding whether to post their first job.
class ForBuildersPage extends StatelessWidget {
  const ForBuildersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SiteShell(
      slivers: [
        SliverToBoxAdapter(
          child: PageHero(
            eyebrow: 'For builders',
            title: "Find a crew you\ndon't have to chase.",
            subtitle:
                'Post a job and see only licence-checked trades who can '
                'actually do it. Talk to them direct — no agencies, no lead '
                'fees, no dud operators wasting your week.',
            ctas: [
              AnimatedCta(label: 'POST YOUR FIRST JOB', route: '/contact'),
              AnimatedCta(
                label: 'See the pricing',
                route: '/pricing',
                filled: false,
                icon: null,
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(child: TrustSafetySection()),
        SliverToBoxAdapter(child: FeaturesSection()),
        SliverToBoxAdapter(child: ComparisonSection()),
        SliverToBoxAdapter(child: TestimonialsSection()),
        SliverToBoxAdapter(child: BottomCtaSection()),
      ],
    );
  }
}
