import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/breakpoints.dart';
import '../../../../../core/design/colors.dart';
import '../widgets/illustrations/badge_seal_illustration.dart';
import '../widgets/phone_frame.dart';
import '../widgets/reveal_on_scroll.dart';
import '../widgets/site_section_frame.dart';

/// "What 'verified' actually means on Jobdun." — two visuals, one story.
///
/// Layout, top-to-bottom:
///   1. Header — eyebrow rule + headline + subhead.
///   2. Stat strip — five hairline-divided metrics. Names the registries
///      and the cadence; the strip is the auditable claim.
///   3. Proof block — the real in-app affordance showing unverified
///      applicants hidden, with the verified seal beside it.
///
/// The 8-row spec list and the "what we'd catch" enumeration were cut:
/// the stat strip already conveys the cadence, and the proof block
/// already shows the result. The section's job is to land the trust
/// signal in under three scrolls, not to enumerate the policy.
class TrustSafetySection extends StatelessWidget {
  const TrustSafetySection({super.key});

  static const _metrics = <_Metric>[
    _Metric(value: '5+', label: 'Registries we check'),
    _Metric(value: 'Daily', label: 'ABN resync'),
    _Metric(value: 'Monthly', label: 'Licence re-verify'),
    _Metric(value: '30 sec', label: 'Sign-up lookup'),
    _Metric(value: '0', label: 'Anonymous accounts'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 32, height: 3, color: c.action),
        const Gap(20),
        Semantics(
          header: true,
          child: Text(
            "What “verified”\nactually means on Jobdun.",
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
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(
            'Every platform uses the word. Here are the registries, the '
            'cadence, and the affordance that actually hides unverified '
            'applicants from a builder.',
            style: tt.bodyLarge!.copyWith(color: c.text2, height: 1.55),
          ),
        ),
      ],
    );

    final proof = _ProofBlock();

    return Container(
      width: double.infinity,
      color: c.surface,
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: SiteSectionFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RevealOnScroll(child: header),
            const Gap(56),
            RevealOnScroll(delayMs: 80, child: _StatStrip(metrics: _metrics)),
            const Gap(56),
            RevealOnScroll(delayMs: 160, child: proof),
          ],
        ),
      ),
    );
  }
}

class _Metric {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.metrics});
  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wide = MediaQuery.sizeOf(context).width >= Bp.tablet;

    final cells = <Widget>[];
    for (var i = 0; i < metrics.length; i++) {
      cells.add(Expanded(child: _StatCell(metric: metrics[i])));
      if (i != metrics.length - 1) {
        cells.add(Container(width: 1, color: c.border));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
        borderRadius: BorderRadius.zero,
      ),
      child: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells)
          : Wrap(
              spacing: 32,
              runSpacing: 32,
              children: [
                for (final m in metrics)
                  SizedBox(width: 140, child: _StatCell(metric: m)),
              ],
            ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metric.value,
          style: tt.headlineMedium!.copyWith(
            color: c.text1,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            height: 1,
          ),
        ),
        const Gap(8),
        Text(
          metric.label.toUpperCase(),
          style: tt.labelSmall!.copyWith(
            color: c.text2,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

/// "Show, don't tell" — the real in-app affordance that hides
/// unverified applicants, with the verified seal beside it.
class _ProofBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= Bp.laptop;

    final phone = SizedBox(
      width: 240,
      child: PhoneFrame(
        asset: 'assets/website/screenshots/20_applicants_job_view.webp',
        semanticLabel:
            'Applicants view showing one hidden applicant — only verified workers are shown.',
        width: 240,
        maxHeight: 540,
      ),
    );

    final seal = BadgeSealIllustration(size: 88);

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'VERIFIED',
          style: tt.labelMedium!.copyWith(
            color: c.action,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        const Gap(16),
        Text(
          'What verified looks like\nin the app.',
          style: tt.headlineSmall!.copyWith(
            color: c.text1,
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -0.3,
          ),
        ),
        const Gap(14),
        Text(
          'One applicant is hidden. Only verified workers are shown. '
          'Builders see the people who passed the gate; unverified '
          'applicants never reach the inbox.',
          style: tt.bodyLarge!.copyWith(color: c.text2, height: 1.6),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: c.background,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 220, child: phone),
                const Gap(16),
                seal,
                const Gap(32),
                Expanded(child: copy),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: phone),
                const Gap(20),
                seal,
                const Gap(20),
                copy,
              ],
            ),
    );
  }
}
