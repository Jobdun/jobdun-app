import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/breakpoints.dart';
import '../../../../../core/design/colors.dart';
import '../widgets/reveal_on_scroll.dart';
import '../widgets/site_section_frame.dart';

/// "The jobs posted on Jobdun right now.": a registry, not a tag cloud.
///
/// Layout (top-to-bottom):
///   1. Header: eyebrow + headline + subhead. The headline names the
///      breadth (12 trades) and the gate (verified every one).
///   2. Roster: an asymmetric 4-card grid. Sparkies is the featured
///      card (wider, left) and carries a longer proof sentence. The
///      other three trades stack on the right at narrower widths.
///      Each card has a real photo, an AU-slang trade name in heavy
///      type, a roster stat in brand orange, a small tracked-caps
///      label, and a one-line proof sentence.
///   3. Live ticker: a single hairline-divided line with a pulsing
///      orange dot, one job-posted metric, and one hires-this-week
///      metric. Reads as activity, not as a social-proof badge.
///   4. CTA link: "See all trades ↓", points at a future /trades page.
///
/// The asymmetric featured-card layout deliberately breaks the
/// "identical card grids" SaaS trap. Each card is the same height
/// (so the row reads as a single band), but the wider featured card
/// carries the weight and the other three cluster on the right.
class TradeCategoriesSection extends StatelessWidget {
  const TradeCategoriesSection({super.key});

  static const _featured = _Trade(
    name: 'Sparkies',
    stat: '2,400+',
    label: 'LICENSED ELECTRICIANS',
    proof:
        'The sparkies wiring new builds, running commercial switchboards, '
        'and pulling compliance on renos. Cert III minimum, public liability '
        'on file, ABN checked at sign-up.',
    asset: 'assets/website/construction/trade-sparky.jpg',
  );

  static const _others = <_Trade>[
    _Trade(
      name: 'Chippies',
      stat: '1,800+',
      label: 'CARPENTERS ON ROSTER',
      proof:
          'From rough framing to fit-out. Every chippy carries a White Card '
          'and a licence the platform has already checked.',
      asset: 'assets/website/construction/trade-chippy.jpg',
    ),
    _Trade(
      name: 'Plumbers',
      stat: '1,200+',
      label: 'PLUMBERS AVAILABLE',
      proof:
          'Draining, rough-in, hot water. Available in your postcode, not '
          'just "Sydney area." Verified and ready to quote.',
      asset: 'assets/website/construction/trade-plumber.jpg',
    ),
    _Trade(
      name: 'Roofers',
      stat: '900+',
      label: 'ROOFERS NATIONWIDE',
      proof:
          'New builds, re-roofing, guttering. All insured, all verified. '
          'Book in a week, not a month.',
      asset: 'assets/website/construction/trade-roofer.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= Bp.laptop;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 32, height: 3, color: c.action),
        const Gap(20),
        Semantics(
          header: true,
          child: Text(
            'Twelve trades.\nVerified every one.',
            style: tt.headlineLarge!.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const Gap(16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            "Australia's biggest building trades, all in one feed. "
            'Licence checked, ABN active, identity confirmed. The same '
            'gate applies whether you hire for a sparky or a chippy.',
            style: tt.bodyLarge!.copyWith(color: c.text2, height: 1.55),
          ),
        ),
      ],
    );

    final roster = wide
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: _TradeCard(trade: _featured, featured: true),
                ),
                const Gap(20),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < _others.length; i++) ...[
                        if (i > 0) const Gap(20),
                        Expanded(child: _TradeCard(trade: _others[i])),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TradeCard(trade: _featured, featured: true),
              const Gap(20),
              for (var i = 0; i < _others.length; i++) ...[
                if (i > 0) const Gap(20),
                _TradeCard(trade: _others[i]),
              ],
            ],
          );

    final ticker = const _LiveTicker();

    final cta = Center(
      child: TextButton(
        onPressed: () {},
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'See all trades',
              style: tt.titleMedium!.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
            const Gap(8),
            Icon(Icons.arrow_downward_rounded, size: 18, color: c.action),
          ],
        ),
      ),
    );

    return Container(
      width: double.infinity,
      color: c.background,
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: SiteSectionFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RevealOnScroll(child: header),
            const Gap(56),
            RevealOnScroll(delayMs: 80, child: roster),
            const Gap(32),
            RevealOnScroll(delayMs: 160, child: ticker),
            const Gap(24),
            RevealOnScroll(delayMs: 220, child: cta),
          ],
        ),
      ),
    );
  }
}

class _Trade {
  const _Trade({
    required this.name,
    required this.stat,
    required this.label,
    required this.proof,
    required this.asset,
  });
  final String name;
  final String stat;
  final String label;
  final String proof;
  final String asset;
}

class _TradeCard extends StatelessWidget {
  const _TradeCard({required this.trade, this.featured = false});
  final _Trade trade;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    trade.asset,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stk) => Container(
                      color: c.surfaceRaised,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.handyman_outlined,
                        color: c.text3,
                        size: 32,
                      ),
                    ),
                  ),
                  // Bottom gradient so the orange rule + name sit on top
                  // of the photo without losing contrast. Solid black at
                  // 70% at the bottom, transparent at the top.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, const Color(0xCC0A1220)],
                        stops: const [0.55, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 28, height: 2, color: c.action),
                        const Gap(10),
                        Text(
                          trade.name.toUpperCase(),
                          style: tt.headlineSmall!.copyWith(
                            color: const Color(0xFFFFFFFF),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: featured ? 24 : 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        trade.stat,
                        style: tt.displaySmall!.copyWith(
                          color: c.action,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.0,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          trade.label,
                          style: tt.labelSmall!.copyWith(
                            color: c.text2,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (featured) ...[
                    const Gap(12),
                    Text(
                      trade.proof,
                      style: tt.bodyMedium!.copyWith(
                        color: c.text1,
                        height: 1.55,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "1 new job posted in the last 30 seconds · 17 hires this week."
/// Hairline-divided row, monospace-feeling tabular-nums line, with
/// a pulsing orange dot at the left that conveys "live" without
/// being a fake notification badge.
class _LiveTicker extends StatefulWidget {
  const _LiveTicker();

  @override
  State<_LiveTicker> createState() => _LiveTickerState();
}

class _LiveTickerState extends State<_LiveTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= Bp.tablet;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: wide
          ? Row(
              children: [
                _Dot(ctrl: _ctrl, color: c.action, reduceMotion: reduceMotion),
                const Gap(12),
                Expanded(
                  child: Text(
                    'LIVE: 1 new job posted in the last 30 seconds.',
                    style: tt.bodyMedium!.copyWith(
                      color: c.text1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                Container(width: 1, height: 18, color: c.border),
                const Gap(20),
                Text(
                  '17 hires this week.',
                  style: tt.bodyMedium!.copyWith(
                    color: c.text2,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Dot(
                      ctrl: _ctrl,
                      color: c.action,
                      reduceMotion: reduceMotion,
                    ),
                    const Gap(10),
                    Text(
                      'LIVE',
                      style: tt.labelSmall!.copyWith(
                        color: c.action,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
                const Gap(8),
                Text(
                  '1 new job posted in the last 30 seconds.',
                  style: tt.bodyMedium!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(6),
                Text(
                  '17 hires this week.',
                  style: tt.bodyMedium!.copyWith(color: c.text2),
                ),
              ],
            ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.ctrl,
    required this.color,
    required this.reduceMotion,
  });
  final AnimationController ctrl;
  final Color color;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }
    return AnimatedBuilder(
      animation: ctrl,
      builder: (ctx, child) {
        final v = ctrl.value;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4 * (1.0 - v)),
                blurRadius: 8 + 4 * v,
                spreadRadius: 1 + 2 * v,
              ),
            ],
          ),
        );
      },
    );
  }
}
