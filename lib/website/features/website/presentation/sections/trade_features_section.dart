import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/breakpoints.dart';
import '../../../../../core/design/colors.dart';
import '../widgets/reveal_on_scroll.dart';
import '../widgets/site_section_frame.dart';

/// Trade feature rows — photo + copy + stat, alternating direction.
/// Replaces the text-only chip grid with a credibility-first layout:
/// seeing real tradespeople at work does more trust work than a tag
/// that says "Sparkies". Three rows (Sparkies, Chippies, Plumbers)
/// cover the platform's highest-density trades without scroll fatigue.
///
/// On desktop: 50/50 split, photo and copy side-by-side.
/// On mobile: full-width photo stacked above the copy block.
class TradeFeaturesSection extends StatelessWidget {
  const TradeFeaturesSection({super.key});

  static const _trades = <_TradeData>[
    _TradeData(
      tag: 'SPARKIES',
      headline: 'Electricians\nwho show up.',
      body:
          'Licence verified before they see the job. Real ABN, real '
          'availability. No ghost listings, no chasing dead numbers.',
      stat: '2,400+',
      statLabel: 'LICENSED ELECTRICIANS',
      asset: 'assets/website/construction/trade-sparky.jpg',
      reversed: false,
    ),
    _TradeData(
      tag: 'CHIPPIES',
      headline: 'Carpenters\nwho frame it right.',
      body:
          'From rough framing to fit-out. Every chippy on Jobdun '
          'carries a White Card and a licence the platform has already '
          'checked.',
      stat: '1,800+',
      statLabel: 'CARPENTERS ON ROSTER',
      asset: 'assets/website/construction/trade-chippy.jpg',
      reversed: true,
    ),
    _TradeData(
      tag: 'PLUMBERS',
      headline: 'Plumbers you\ncan actually reach.',
      body:
          'Draining, rough-in, hot water. Available in your postcode, '
          'not just "Sydney area." Verified and ready to quote.',
      stat: '1,200+',
      statLabel: 'PLUMBERS AVAILABLE',
      asset: 'assets/website/construction/trade-plumber.jpg',
      reversed: false,
    ),
    _TradeData(
      tag: 'ROOFERS',
      headline: 'Roofers who\nfinish the job.',
      body:
          'New builds, re-roofing, guttering. All insured, all '
          'verified. Book in a week, not a month.',
      stat: '900+',
      statLabel: 'ROOFERS NATIONWIDE',
      asset: 'assets/website/construction/trade-roofer.jpg',
      reversed: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final w = MediaQuery.sizeOf(context).width;
    final stacked = w < Bp.tablet;

    return Container(
      width: double.infinity,
      color: c.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 88, bottom: 48),
            child: SiteSectionFrame(
              child: RevealOnScroll(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Orange eyebrow rule
                    Container(width: 32, height: 3, color: c.action),
                    const Gap(20),
                    Semantics(
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
                    const Gap(12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(
                        'From the sparky wiring a new build to the chippie '
                        'framing it — if you hold a licence, you belong here.',
                        style: tt.bodyLarge!.copyWith(
                          color: c.text2,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Trade rows
          for (var i = 0; i < _trades.length; i++) ...[
            if (i > 0)
              Container(
                height: 1,
                width: double.infinity,
                color: c.border,
              ),
            RevealOnScroll(
              delayMs: i * 60,
              child: _TradeRow(
                data: _trades[i],
                stacked: stacked,
              ),
            ),
          ],
          const Gap(80),
        ],
      ),
    );
  }
}

class _TradeRow extends StatelessWidget {
  const _TradeRow({required this.data, required this.stacked});

  final _TradeData data;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final photo = _TradePhoto(asset: data.asset);
    final copy = _TradeCopy(data: data);

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 260, width: double.infinity, child: photo),
          copy,
        ],
      );
    }

    // Desktop: side-by-side, alternating which side the photo is on.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: data.reversed
            ? [Expanded(child: copy), Expanded(child: photo)]
            : [Expanded(child: photo), Expanded(child: copy)],
      ),
    );
  }
}

class _TradePhoto extends StatelessWidget {
  const _TradePhoto({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        errorBuilder: (context, error, stack) => Container(
          color: context.c.surfaceRaised,
        ),
      ),
    );
  }
}

class _TradeCopy extends StatelessWidget {
  const _TradeCopy({required this.data});

  final _TradeData data;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      color: c.surface,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Trade tag pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: c.action.withValues(alpha: 0.1),
              border: Border.all(color: c.action.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              data.tag,
              style: tt.labelSmall!.copyWith(
                color: c.action,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
          ),
          const Gap(16),
          Text(
            data.headline,
            style: tt.headlineMedium!.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: -0.3,
            ),
          ),
          const Gap(14),
          Text(
            data.body,
            style: tt.bodyLarge!.copyWith(color: c.text2, height: 1.65),
          ),
          const Gap(24),
          // Stat
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                data.stat,
                style: tt.displaySmall!.copyWith(
                  color: c.action,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.0,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10), // Gap incompatible with baseline alignment
              Text(
                data.statLabel,
                style: tt.labelSmall!.copyWith(
                  color: c.text2,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TradeData {
  const _TradeData({
    required this.tag,
    required this.headline,
    required this.body,
    required this.stat,
    required this.statLabel,
    required this.asset,
    required this.reversed,
  });

  final String tag;
  final String headline;
  final String body;
  final String stat;
  final String statLabel;
  final String asset;
  final bool reversed;
}
