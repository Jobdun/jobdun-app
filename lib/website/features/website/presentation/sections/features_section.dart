import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/theme/app_icons.dart';
import '../widgets/hover_lift_card.dart';
import '../widgets/reveal_on_scroll.dart';
import '../widgets/site_section_frame.dart';

/// "Everything the job needs, nothing it doesn't." — a six-up grid of the
/// concrete things the app actually does. The conceptual "how it works"
/// section sells the idea; this one names the features so a sceptical tradie
/// can see exactly what they get.
class FeaturesSection extends StatelessWidget {
  const FeaturesSection({super.key});

  static const _features = <_Feature>[
    _Feature(
      icon: AppIcons.verified,
      title: 'Licence & ABN checks',
      body:
          'Every trade is cross-checked against the national licence '
          'register. Every builder carries a verified ABN.',
    ),
    _Feature(
      icon: AppIcons.location,
      title: 'Local job matching',
      body:
          'Set the suburb you work out of and the feed only shows jobs '
          "that are actually drivable — no 80km guesswork.",
    ),
    _Feature(
      icon: AppIcons.messageText,
      title: 'Talk direct, in-app',
      body:
          'Message the builder or the trade straight away. No agencies, '
          'no go-betweens, no phone tag.',
    ),
    _Feature(
      icon: AppIcons.receipt,
      title: 'Quote on apply',
      body:
          'Send your price with the application. The job pays what you '
          'both agreed — written down, up front.',
    ),
    _Feature(
      icon: AppIcons.star,
      title: 'Ratings that follow you',
      body:
          'Finish the job, earn the review. A solid track record puts '
          'you at the top of the next builder\'s list.',
    ),
    _Feature(
      icon: AppIcons.wallet,
      title: 'No fees, no take rate',
      body:
          "No subscription, no premium tier, and we never skim a cut of "
          'your pay. The job pays you, in full.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final w = MediaQuery.sizeOf(context).width;
    final columns = w >= 980
        ? 3
        : w >= 640
        ? 2
        : 1;

    return Container(
      width: double.infinity,
      color: c.background,
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: SiteSectionFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RevealOnScroll(
              child: Semantics(
                header: true,
                child: Text(
                  "Everything the job needs.\nNothing it doesn't.",
                  style: tt.headlineLarge!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),
            const Gap(40),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 20.0;
                final cardWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var i = 0; i < _features.length; i++)
                      SizedBox(
                        width: columns == 1 ? double.infinity : cardWidth,
                        child: RevealOnScroll(
                          delayMs: (i % columns) * 80,
                          child: _FeatureCard(feature: _features[i]),
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

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return HoverLiftCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: c.actionBg,
              borderRadius: BorderRadius.circular(AppRadius.btn),
            ),
            child: Icon(feature.icon, size: 24, color: c.actionInk),
          ),
          const Gap(20),
          Text(
            feature.title,
            style: tt.titleLarge!.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const Gap(8),
          Text(
            feature.body,
            style: tt.bodyMedium!.copyWith(color: c.text2, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _Feature {
  const _Feature({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
}
