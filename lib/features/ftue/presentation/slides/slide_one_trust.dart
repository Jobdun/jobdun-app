import 'package:flutter/material.dart';

import '../widgets/ftue_hero_photo.dart';
import '../widgets/ftue_slide.dart';

// Slide 1 — "Only verified. No timewasters." Establishes the trust premise
// before any other claim. Hero photo: a tradie at a real worksite (sourced
// from Unsplash for v1; see assets/images/ftue/README.md).
//
// No NEXT button on slides 1 + 2: the bottom indicator dots already signal
// "this is a carousel", swipe is the universal mobile carousel gesture,
// and dropping the chrome lets the photo + stencil headline carry the
// slide. The orange c.action accent stays reserved for slide 3's role
// CTAs — the only real decision in the whole flow.
class SlideOneTrust extends StatelessWidget {
  const SlideOneTrust({super.key});

  static const heroAsset = 'assets/images/ftue/slide_1_verified.jpg';

  @override
  Widget build(BuildContext context) {
    return const FtueSlide(
      visual: FtueHeroPhoto(
        assetPath: heroAsset,
        slideIndex: 0,
        semanticLabel: 'Verified tradie working on a construction site',
      ),
      headlineLine1: 'ONLY VERIFIED.',
      headlineLine2: 'NO TIMEWASTERS.',
      bodyLine1: 'Every trade licence-checked.',
      bodyLine2: 'Every builder verified.',
    );
  }
}
