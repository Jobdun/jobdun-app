import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/breakpoints.dart';
import '../../../../../core/design/colors.dart';
import '../widgets/illustrations/badge_seal_illustration.dart';
import '../widgets/phone_frame.dart';
import '../widgets/reveal_on_scroll.dart';
import '../widgets/site_section_frame.dart';

/// "What 'verified' actually means on Jobdun." — turns the repeated
/// verification claim into an auditable mechanism. Every platform uses
/// the word; this section names the registries, the cadence, the
/// specific failure modes the checks catch, and shows the actual UI
/// affordance that hides unverified applicants.
///
/// Layout, top-to-bottom:
///   1. Header (eyebrow rule + headline + subhead).
///   2. Stat strip — five hairline-divided metrics, each a number and
///      an all-caps label. Names the registries and the cadence.
///   3. Two-column "at sign-up" (gates) vs "every day" (monitoring)
///      so a sceptical reader sees the difference between a one-time
///      upload and an ongoing watch.
///   4. "What we'd actually catch" — the specific failure modes the
///      checks surface, framed as the competitive edge over platforms
///      that only check at sign-up.
///   5. Proof block — a real screenshot of the in-app affordance that
///      hides unverified applicants, with the verified seal floating
///      beside it. "Show, don't tell" the verification claim.
///
/// No decorative icons on the spec rows; the orange eyebrow rule and
/// the verified-seal vector carry the brand instead.
class TrustSafetySection extends StatelessWidget {
  const TrustSafetySection({super.key});

  static const _metrics = <_Metric>[
    _Metric(value: '5+', label: 'Registries we check'),
    _Metric(value: 'Daily', label: 'ABN resync'),
    _Metric(value: 'Monthly', label: 'Licence re-verify'),
    _Metric(value: '30 sec', label: 'Sign-up lookup'),
    _Metric(value: '0', label: 'Anonymous accounts'),
  ];

  static const _gates = <_Check>[
    _Check(
      title: 'National Licence Register',
      body:
          'The trade registers a licence number. We look it up against the '
          'national register in under thirty seconds. No match, no apply.',
    ),
    _Check(
      title: 'ABN — active',
      body:
          'Cross-checked against the Australian Business Register before the '
          'account can post or apply. Cancelled, struck-off or deregistered '
          'ABNs fail the gate.',
    ),
    _Check(
      title: 'Identity confirmed',
      body:
          'Real name, real face, real phone. The same identity is reused '
          'on every job — anonymous profiles cannot exist on Jobdun.',
    ),
    _Check(
      title: 'Insurance on file',
      body:
          'Public liability and the cover relevant to the trade are '
          'recorded against the profile before the first message.',
    ),
  ];

  static const _monitoring = <_Check>[
    _Check(
      title: 'ABN — still active',
      body:
          'Re-checked against the ABR every day. Strike-offs, insolvencies '
          'and windings-up surface within twenty-four hours.',
    ),
    _Check(
      title: 'Licence — still valid',
      body:
          'Re-verified monthly. A cancelled or expired licence takes the '
          'profile offline the next morning.',
    ),
    _Check(
      title: 'Insurance — still current',
      body:
          'Expiry dates are tracked. The profile is paused the day the '
          'cover lapses, not the day the tradie remembers to renew.',
    ),
    _Check(
      title: 'Reviews from real jobs',
      body:
          'Ratings come only from work completed through Jobdun — never '
          'anonymous drive-by reviews, never imported from elsewhere.',
    ),
  ];

  static const _catches = <String>[
    'A sparky whose ABN was struck off three months ago and is still trading.',
    'A builder with a cancelled builder licence nobody checked at the renewal.',
    'A tradie operating outside their licensed category — sparky doing plumbing.',
    'An anonymous account trying to apply without a face on file.',
    'A public liability policy that expired last Tuesday and was never renewed.',
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
            'cadence, and the specific cases our checks catch before '
            'anyone picks up a single job.',
            style: tt.bodyLarge!.copyWith(color: c.text2, height: 1.55),
          ),
        ),
      ],
    );

    final metrics = _StatStrip(metrics: _metrics);

    final twoUp = wide
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                Expanded(
                  child: _CheckColumn(label: 'AT SIGN-UP', checks: _gates),
                ),
                Gap(48),
                Expanded(
                  child: _CheckColumn(label: 'EVERY DAY', checks: _monitoring),
                ),
              ],
            ),
          )
        : const Column(
            children: [
              _CheckColumn(label: 'AT SIGN-UP', checks: _gates),
              Gap(48),
              _CheckColumn(label: 'EVERY DAY', checks: _monitoring),
            ],
          );

    final catches = _CatchesBlock(items: _catches);

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
            RevealOnScroll(delayMs: 80, child: metrics),
            const Gap(72),
            RevealOnScroll(delayMs: 160, child: twoUp),
            const Gap(72),
            RevealOnScroll(delayMs: 240, child: catches),
            const Gap(72),
            RevealOnScroll(delayMs: 320, child: proof),
          ],
        ),
      ),
    );
  }
}

/// One cell of the metric strip. Big number on top, all-caps label
/// below, hairline border on the right so adjacent cells share one
/// rule (no per-cell borders — keeps the read as a single strip).
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
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
        borderRadius: BorderRadius.zero,
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
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

class _Check {
  const _Check({required this.title, required this.body});
  final String title;
  final String body;
}

class _CheckColumn extends StatelessWidget {
  const _CheckColumn({required this.label, required this.checks});

  final String label;
  final List<_Check> checks;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: tt.labelMedium!.copyWith(
            color: c.action,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        const Gap(20),
        for (final check in checks) _CheckRow(check: check),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});
  final _Check check;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: c.border),
          const Gap(18),
          Text(
            check.title,
            style: tt.titleMedium!.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(6),
          Text(
            check.body,
            style: tt.bodyMedium!.copyWith(color: c.text2, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _CatchesBlock extends StatelessWidget {
  const _CatchesBlock({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 28, height: 3, color: c.action),
        const Gap(16),
        Semantics(
          header: true,
          child: Text(
            'What we’d actually catch.',
            style: tt.titleLarge!.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Gap(8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(
            'The cases the unverified platforms miss. Every one of these '
            'has shown up on Jobdun and been removed before a single '
            'builder saw the profile.',
            style: tt.bodyMedium!.copyWith(color: c.text2, height: 1.6),
          ),
        ),
        const Gap(20),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: c.action,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const Gap(14),
                Expanded(
                  child: Text(
                    item,
                    style: tt.bodyMedium!.copyWith(
                      color: c.text1,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The "show, don't tell" block — a real screenshot of the in-app
/// affordance that hides unverified applicants, with the verified
/// seal floating beside it. The screenshot is the proof; the seal is
/// the brand; the copy underneath names what's being shown.
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
