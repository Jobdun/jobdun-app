import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/breakpoints.dart';
import '../../../../../core/design/colors.dart';
import '../widgets/count_up_text.dart';
import '../widgets/reveal_on_scroll.dart';
import '../widgets/site_section_frame.dart';

/// Trust band — four numbers that prove the "only verified" promise the rest
/// of the page makes. Sits on `c.surface` so it reads as a distinct ledger
/// strip between the hero and the editorial prose.
///
/// Figures are indicative placeholders the client swaps for live platform
/// numbers — kept realistic for the AU market (8 capital cities, etc.).
class TrustStatsSection extends StatelessWidget {
  const TrustStatsSection({super.key});

  static const _stats = <_Stat>[
    _Stat(value: 12400, label: 'LICENCES VERIFIED'),
    _Stat(value: 3200, label: 'BUILDERS HIRING'),
    _Stat(value: 100, suffix: '%', label: 'CHECKED BEFORE CONTACT'),
    _Stat(value: 8, label: 'CAPITAL CITIES COVERED'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = MediaQuery.sizeOf(context).width;
    final columns = w >= Bp.laptop ? 4 : 2;

    return Container(
      width: double.infinity,
      color: c.surface,
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: SiteSectionFrame(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = 24.0;
            final itemWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: 40,
              children: [
                for (var i = 0; i < _stats.length; i++)
                  SizedBox(
                    width: itemWidth,
                    child: RevealOnScroll(
                      delayMs: i * 90,
                      child: _StatBlock(stat: _stats[i]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.stat});

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 28, height: 3, color: c.action),
        const Gap(16),
        CountUpText(
          value: stat.value,
          suffix: stat.suffix,
          style: tt.displaySmall!.copyWith(
            color: c.text1,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const Gap(6),
        Text(
          stat.label,
          style: tt.labelMedium!.copyWith(color: c.text2, letterSpacing: 1.0),
        ),
      ],
    );
  }
}

class _Stat {
  const _Stat({required this.value, required this.label, this.suffix = ''});
  final int value;
  final String suffix;
  final String label;
}
