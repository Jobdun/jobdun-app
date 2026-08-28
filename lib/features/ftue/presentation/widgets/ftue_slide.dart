import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'ftue_caption.dart';
import 'ftue_hero.dart';

/// One card floating over the hero, placed as a fraction of the hero box.
///
/// The Figma frame is 393x567 (node 17:5084), so a card the mock puts at
/// `left: 272, top: 87` is declared as `FtueOverlay(left: 272 / 393, top: 87 /
/// 567, …)`. Fractions rather than logical pixels because the hero stretches
/// to whatever height is left over after the role sheet claims its space — a
/// fixed offset would drift off a short screen.
///
/// Anchor to exactly one horizontal edge. Cards on the right side of the hero
/// should use [right] (measured from the hero's right edge) so a card that
/// sizes to its content — a suburb pin carrying a live place name — grows
/// inwards instead of off the screen.
class FtueOverlay {
  const FtueOverlay({
    required this.top,
    required this.child,
    this.left,
    this.right,
  }) : assert(
         (left == null) != (right == null),
         'Anchor an overlay to exactly one of left / right.',
       );

  /// 0–1 from the hero's left edge.
  final double? left;

  /// 0–1 from the hero's right edge.
  final double? right;

  /// 0–1 down the hero.
  final double top;

  final Widget child;
}

/// Layout shared by all three onboarding slides: a full-bleed hero, any number
/// of cards floating over it, and the two-tone headline anchored to the bottom.
///
/// Everything here swipes. The role sheet below does not — see [FtueRoleSheet].
class FtueSlide extends StatelessWidget {
  const FtueSlide({
    super.key,
    required this.assetPath,
    required this.slideIndex,
    required this.semanticLabel,
    required this.lead,
    required this.accent,
    required this.controller,
    required this.slideCount,
    this.overlays = const [],
  });

  final String assetPath;
  final int slideIndex;
  final String semanticLabel;

  /// Headline in ink, hard-broken after.
  final String lead;

  /// Headline in orange, wraps on its own.
  final String accent;

  final PageController controller;
  final int slideCount;
  final List<FtueOverlay> overlays;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          fit: StackFit.expand,
          children: [
            FtueHero(
              assetPath: assetPath,
              slideIndex: slideIndex,
              semanticLabel: semanticLabel,
            ),
            for (final (i, o) in overlays.indexed)
              Positioned(
                left: o.left == null ? null : w * o.left!,
                right: o.right == null ? null : w * o.right!,
                top: h * o.top,
                // Staggered so the badges land one after the other rather than
                // popping in as a block.
                child: reduceMotion
                    ? o.child
                    : o.child
                          .animate()
                          .fadeIn(
                            delay: Duration(milliseconds: 220 + i * 90),
                            duration: const Duration(milliseconds: 200),
                          )
                          .slideY(begin: 0.12, curve: Curves.easeOutCubic),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FtueCaption(
                lead: lead,
                accent: accent,
                controller: controller,
                slideCount: slideCount,
              ),
            ),
          ],
        );
      },
    );
  }
}
