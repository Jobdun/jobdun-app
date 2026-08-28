import 'package:flutter/material.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../widgets/ftue_overlay_card.dart';
import '../widgets/ftue_slide.dart';

/// Slide 1 — "Only verified. No timewasters." Establishes the trust premise
/// before any other claim, because it's the objection every tradie brings to a
/// jobs app.
///
/// The two seals floating over the photo (Figma nodes 60:141 and 60:150) are
/// the proof: licence checks and ID checks are the things Jobdun actually
/// does, stated as badges rather than body copy.
class SlideOneTrust extends StatelessWidget {
  const SlideOneTrust({
    super.key,
    required this.controller,
    required this.slideCount,
  });

  static const heroAsset = 'assets/images/ftue/slide_1_verified.webp';

  final PageController controller;
  final int slideCount;

  @override
  Widget build(BuildContext context) {
    return FtueSlide(
      assetPath: heroAsset,
      slideIndex: 0,
      semanticLabel: 'A licence-checked tradie in Jobdun hi-vis on site',
      lead: 'ONLY VERIFIED.',
      // Hard break, not a wrap. The mock (node 50:9944) sets this as three
      // separate lines — "NO" alone is what gives the stack its punch, and at
      // 32/1.2 the phrase would otherwise sit on one line.
      accent: 'NO\nTIMEWASTERS.',
      controller: controller,
      slideCount: slideCount,
      overlays: const [
        FtueOverlay(
          // Mock puts this at left 272 with a 91-wide card, i.e. 30 in from
          // the right edge — anchored that way so it can never clip.
          right: 30 / 393,
          top: 87 / 567,
          child: FtueOverlayCard.stacked(
            label: 'Licensed & Verified',
            icon: AppIcons.shieldCheckFilled,
          ),
        ),
        FtueOverlay(
          left: 37 / 393,
          top: 235 / 567,
          child: FtueOverlayCard.stacked(
            label: 'ID Checked',
            icon: AppIcons.idCardFilled,
          ),
        ),
      ],
    );
  }
}
