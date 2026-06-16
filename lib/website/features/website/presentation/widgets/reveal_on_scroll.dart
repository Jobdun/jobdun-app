import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Fade-and-rise entrance for marketing-site content.
///
/// The site is a lazily-built `CustomScrollView`, so a section's widgets are
/// constructed roughly when they scroll near the viewport — playing the effect
/// on build reads as "reveal on scroll" without a visibility detector.
///
/// Honours reduced-motion (`MediaQuery.disableAnimations`, which Flutter web
/// wires to the `prefers-reduced-motion` media query): when set, the child is
/// returned as-is, fully visible, with no animation.
class RevealOnScroll extends StatelessWidget {
  const RevealOnScroll({super.key, required this.child, this.delayMs = 0});

  final Widget child;

  /// Stagger offset so items in a row cascade in.
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) return child;

    return child
        .animate()
        .fadeIn(duration: 420.ms, delay: delayMs.ms, curve: Curves.easeOut)
        .moveY(
          begin: 18,
          end: 0,
          duration: 460.ms,
          delay: delayMs.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
