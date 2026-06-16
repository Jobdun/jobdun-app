import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/theme/app_icons.dart';
import '../widgets/reveal_on_scroll.dart';
import '../widgets/site_section_frame.dart';

/// "Built for every trade on site." — a confident title, a one-line qualifier,
/// then a wrap of AU-slang trade chips. The chips are the social proof of
/// breadth: a chippie and a sparky both see themselves here.
class TradeCategoriesSection extends StatelessWidget {
  const TradeCategoriesSection({super.key});

  static const _trades = <_Trade>[
    _Trade('Chippies', AppIcons.myJobsOutline),
    _Trade('Sparkies', AppIcons.lightning),
    _Trade('Plumbers', AppIcons.drop),
    _Trade('Brickies', AppIcons.building),
    _Trade('Painters', AppIcons.paintRoller),
    _Trade('Concreters', AppIcons.hardHat),
    _Trade('Roofers', AppIcons.homeOutline),
    _Trade('Landscapers', AppIcons.tree),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: c.background,
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: SiteSectionFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RevealOnScroll(
              child: Semantics(
                header: true,
                child: Text(
                  'Built for every trade on site.',
                  style: tt.headlineLarge!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),
            const Gap(12),
            RevealOnScroll(
              delayMs: 60,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Text(
                  'From the sparky wiring a new build to the chippie framing '
                  'it — if you hold a licence, you belong here.',
                  style: tt.bodyLarge!.copyWith(color: c.text2, height: 1.55),
                ),
              ),
            ),
            const Gap(32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < _trades.length; i++)
                  RevealOnScroll(
                    delayMs: 120 + i * 50,
                    child: _TradeChip(trade: _trades[i]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TradeChip extends StatelessWidget {
  const _TradeChip({required this.trade});

  final _Trade trade;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.btn),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(trade.icon, size: 18, color: c.action),
          const Gap(10),
          Text(
            trade.label,
            style: tt.titleSmall!.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Trade {
  const _Trade(this.label, this.icon);
  final String label;
  final IconData icon;
}
