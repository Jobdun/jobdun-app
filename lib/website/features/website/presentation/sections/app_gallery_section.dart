import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../../../../app/theme/breakpoints.dart';
import '../widgets/orange_rule.dart';
import '../widgets/phone_frame.dart';
import '../widgets/roadmap_bar.dart';
import '../widgets/site_section_frame.dart';

/// A horizontal **roadmap** that shows the user journey from post
/// to hire. Three milestones connected by an animated progress
/// line that draws left to right when the section enters the
/// viewport. Each milestone is a phone screenshot with a large
/// number, headline, and caption. The connector line + moving
/// pulse tells the story at a glance: *this is what happens, in
/// order*. On mobile the milestones stack vertically.
///
/// Phones are 9:19.5 aspect. On mobile (<960) the milestones
/// stack vertically with a vertical connector.
class AppGallerySection extends StatefulWidget {
  const AppGallerySection({super.key});

  @override
  State<AppGallerySection> createState() => _AppGallerySectionState();
}

class _AppGallerySectionState extends State<AppGallerySection>
    with SingleTickerProviderStateMixin {
  // Drives the connector line draw + the phone fade-in.
  late final AnimationController _controller;
  late final Animation<double> _lineAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _lineAnimation = CurvedAnimation(
      parent: _controller,
      curve: const _RoadmapCurve(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final w = MediaQuery.sizeOf(context).width;
    final stacked = w < Bp.laptop;

    return Container(
      width: double.infinity,
      color: c.background,
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: SiteSectionFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Center(child: OrangeRule(width: 48, thickness: 3)),
            const Gap(32),
            Text(
              'The flow.',
              textAlign: TextAlign.center,
              style: tt.displaySmall!.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w700,
                height: 1.05,
                letterSpacing: -0.5,
              ),
            ),
            const Gap(12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Text(
                'Post the job. Get verified applicants. Hire the right one. '
                'Three steps. Twenty seconds to your first shortlist.',
                textAlign: TextAlign.center,
                style: tt.bodyLarge!.copyWith(color: c.text2, height: 1.55),
              ),
            ),
            const Gap(72),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                if (stacked) {
                  return _StackedRoadmap(progress: _lineAnimation.value);
                }
                return _HorizontalRoadmap(progress: _lineAnimation.value);
              },
            ),
            const Gap(48),
            const Center(child: OrangeRule(width: 48, thickness: 3)),
          ],
        ),
      ),
    );
  }
}

class _RoadmapCurve extends Curve {
  const _RoadmapCurve();
  @override
  double transformInternal(double t) => 1 - (1 - t) * (1 - t);
}

/// Horizontal roadmap (≥960). Three milestones in a row,
/// connected by an animated line at the node-dot level.
class _HorizontalRoadmap extends StatelessWidget {
  const _HorizontalRoadmap({required this.progress});
  final double progress;

  // Phone height + gap to node dot. The connector line is drawn
  // at the centre of the node dot, so the y is:
  //   phoneH + gap + nodeR
  static const _phoneH = 440.0;
  static const _gapToNode = 24.0;
  static const _nodeR = 12.0; // half of 24px node diameter
  static const _connectorY = _phoneH + _gapToNode + _nodeR;

  @override
  Widget build(BuildContext context) {
    const milestones = _milestones;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = constraints.maxWidth / 3;
        final lineLeft = columnWidth / 2;
        final lineRight = constraints.maxWidth - columnWidth / 2;
        return Stack(
          children: [
            // The three milestone columns (drawn first, so the
            // connector line renders on top of them at the
            // node-dot y).
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < milestones.length; i++)
                  Expanded(
                    child: _MilestoneColumn(
                      milestone: milestones[i],
                      index: i,
                      progress: progress,
                    ),
                  ),
              ],
            ),
            // Animated connector line at the node-dot y, on top
            // of the columns. Height is the line thickness.
            Positioned(
              left: lineLeft,
              top: _connectorY,
              width: lineRight - lineLeft,
              height: 2,
              child: _AnimatedConnectorLine(progress: progress),
            ),
          ],
        );
      },
    );
  }
}

/// Stacked roadmap (<960). Three milestones in a column,
/// connected by a vertical animated line.
class _StackedRoadmap extends StatelessWidget {
  const _StackedRoadmap({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vertical connector line.
          SizedBox(
            width: 48,
            child: _AnimatedConnectorLine(progress: progress, vertical: true),
          ),
          const Gap(24),
          // The three milestone rows.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _milestones.length; i++) ...[
                  _MilestoneRow(
                    milestone: _milestones[i],
                    index: i,
                    progress: progress,
                  ),
                  if (i < _milestones.length - 1) const Gap(40),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The animated connector line. Draws from start to end as
/// `progress` goes 0 → 1, with a moving pulse that travels
/// along the line as it draws.
class _AnimatedConnectorLine extends StatelessWidget {
  const _AnimatedConnectorLine({required this.progress, this.vertical = false});
  final double progress;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return LayoutBuilder(
      builder: (context, constraints) {
        final length = vertical ? constraints.maxHeight : constraints.maxWidth;
        final drawnLength = length * progress;
        return Stack(
          children: [
            // Faint full track.
            Positioned.fill(
              child: vertical
                  ? RoadmapBar(color: c.border)
                  : RoadmapBar(color: c.border, thickness: 2),
            ),
            // Drawn portion: solid orange, clipped to progress.
            if (drawnLength > 0)
              Positioned.fill(
                child: ClipRect(
                  clipper: RoadmapProgressClipper(
                    progress: progress,
                    vertical: vertical,
                  ),
                  child: vertical
                      ? RoadmapBar(color: c.action)
                      : RoadmapBar(color: c.action, thickness: 2),
                ),
              ),
            // Moving pulse, dot that travels along the line as
            // it draws.
            if (drawnLength > 4)
              Positioned(
                left: vertical ? 0 : drawnLength - 8,
                top: vertical ? drawnLength - 8 : 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: c.action,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.action.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One milestone: phone above, node dot, headline + caption.
class _MilestoneColumn extends StatelessWidget {
  const _MilestoneColumn({
    required this.milestone,
    required this.index,
    required this.progress,
  });
  final _Milestone milestone;
  final int index;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    // Stagger: phone 0/0.3/0.6, node 0.25/0.5/0.75.
    final phoneDelay = index * 0.3;
    final phoneProgress = ((progress - phoneDelay) / (1.0 - phoneDelay)).clamp(
      0.0,
      1.0,
    );
    final nodeDelay = (index + 1) * 0.25;
    final nodeProgress = ((progress - nodeDelay) / (1.0 - nodeDelay)).clamp(
      0.0,
      1.0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Phone: fades in + scales up + slides up.
        Opacity(
          opacity: phoneProgress,
          child: Transform.translate(
            offset: Offset(0, (1 - phoneProgress) * 24),
            child: Transform.scale(
              scale: 0.92 + 0.08 * phoneProgress,
              child: PhoneFrame(
                asset: milestone.asset,
                width: 200,
                maxHeight: 440,
              ),
            ),
          ),
        ),
        const Gap(24),
        // Node dot: pops in.
        Opacity(
          opacity: nodeProgress,
          child: Transform.scale(
            scale: 0.6 + 0.4 * nodeProgress,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: nodeProgress > 0.5 ? c.action : c.surface,
                shape: BoxShape.circle,
                border: Border.all(color: c.action, width: 3),
                boxShadow: [
                  if (nodeProgress >= 1.0)
                    BoxShadow(
                      color: c.action.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Center(
                child: Text(
                  milestone.number,
                  style: tt.labelLarge!.copyWith(
                    color: nodeProgress > 0.5 ? c.onAction : c.action,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
        const Gap(20),
        // Headline + caption: fade in after the node.
        Opacity(
          opacity: nodeProgress,
          child: Transform.translate(
            offset: Offset(0, (1 - nodeProgress) * 8),
            child: Column(
              children: [
                Text(
                  milestone.headline,
                  textAlign: TextAlign.center,
                  style: tt.headlineSmall!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
                const Gap(8),
                Text(
                  milestone.caption,
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium!.copyWith(color: c.text2, height: 1.55),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Stacked milestone row (mobile).
class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.milestone,
    required this.index,
    required this.progress,
  });
  final _Milestone milestone;
  final int index;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final phoneDelay = index * 0.3;
    final phoneProgress = ((progress - phoneDelay) / (1.0 - phoneDelay)).clamp(
      0.0,
      1.0,
    );
    return Opacity(
      opacity: phoneProgress,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhoneFrame(asset: milestone.asset, width: 100, maxHeight: 220),
          const Gap(20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${milestone.number} · ${milestone.eyebrow.toUpperCase()}',
                  style: tt.labelLarge!.copyWith(
                    color: c.action,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const Gap(8),
                Text(
                  milestone.headline,
                  style: tt.titleLarge!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const Gap(8),
                Text(
                  milestone.caption,
                  style: tt.bodyMedium!.copyWith(color: c.text2, height: 1.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Milestone {
  const _Milestone({
    required this.number,
    required this.eyebrow,
    required this.headline,
    required this.caption,
    required this.asset,
  });
  final String number;
  final String eyebrow;
  final String headline;
  final String caption;
  final String asset;
}

const _milestones = <_Milestone>[
  _Milestone(
    number: '01',
    eyebrow: 'Post',
    headline: 'Post the job in 20s.',
    caption:
        'Title, trade, location, pay. Five steps. Verified crews see it first.',
    asset: 'assets/website/screenshots/posted-job.webp',
  ),
  _Milestone(
    number: '02',
    eyebrow: 'Match',
    headline: 'Applicants, instant.',
    caption:
        'Licence-checked tradies within 30 km apply. Shortlist, message, decide.',
    asset: 'assets/website/screenshots/17_builder_home_with_applicant.webp',
  ),
  _Milestone(
    number: '03',
    eyebrow: 'Hire',
    headline: 'Hired. Job filled.',
    caption:
        'One tap locks the rate, flips the job to FILLED, and opens the chat.',
    asset: 'assets/website/screenshots/job-filled.webp',
  ),
];
