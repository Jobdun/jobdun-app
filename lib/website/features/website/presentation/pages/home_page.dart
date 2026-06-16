import 'package:flutter/material.dart';

import '../sections/app_gallery_section.dart';
import '../sections/bottom_cta_section.dart';
import '../sections/built_for_section.dart';
import '../sections/comparison_section.dart';
import '../sections/faq_section.dart';
import '../sections/features_section.dart';
import '../sections/hero_section.dart';
import '../sections/how_it_works_section.dart';
import '../sections/roles_section.dart';
import '../sections/story_scroll_section.dart';
import '../sections/testimonials_section.dart';
import '../sections/trade_categories_section.dart';
import '../sections/trust_safety_section.dart';
import '../sections/trust_stats_section.dart';
import '../sections/values_strip.dart';
import '../widgets/orange_rule.dart';
import '../widgets/site_shell.dart';
import '../widgets/watermark_mark.dart';

/// The marketing home page — the full single-scroll story. Chrome (nav,
/// footer, blueprint background, scroll-driven nav state) lives in [SiteShell];
/// this page only declares the section rhythm. No two adjacent sections share
/// a layout, and the surface/background colour alternates for cadence.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SiteShell(
      slivers: [
        SliverToBoxAdapter(child: HeroSection()),
        SliverToBoxAdapter(child: TrustStatsSection()),
        // BuiltFor carries the watermark hammer-J anchor behind its prose.
        SliverToBoxAdapter(
          child: Stack(
            children: [
              BuiltForSection(),
              Positioned.fill(
                child: IgnorePointer(
                  child: WatermarkMark(
                    alignment: Alignment.topRight,
                    size: 320,
                    opacity: 0.045,
                    tilt: -0.05,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Proof of the verification claim the editorial just made.
        SliverToBoxAdapter(child: TrustSafetySection()),
        // Sticky-scroll product walkthrough — real-device captures.
        SliverToBoxAdapter(child: StoryScrollSection()),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: OrangeRule(width: 64, thickness: 4)),
          ),
        ),
        SliverToBoxAdapter(child: ValuesStrip()),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: OrangeRule(width: 48, thickness: 3)),
          ),
        ),
        SliverToBoxAdapter(child: HowItWorksSection()),
        SliverToBoxAdapter(child: FeaturesSection()),
        // The competitive wedge — proves the "no fees" feature.
        SliverToBoxAdapter(child: ComparisonSection()),
        SliverToBoxAdapter(child: RolesSection()),
        SliverToBoxAdapter(child: TradeCategoriesSection()),
        SliverToBoxAdapter(child: TestimonialsSection()),
        SliverToBoxAdapter(child: AppGallerySection()),
        // Objection-handling before the final ask.
        SliverToBoxAdapter(child: FaqSection()),
        SliverToBoxAdapter(child: BottomCtaSection()),
      ],
    );
  }
}
