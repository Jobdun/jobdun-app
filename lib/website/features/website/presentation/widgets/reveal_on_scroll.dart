import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Fade-and-rise entrance for marketing-site content, fired when the element
/// actually scrolls into view (not merely when the lazy sliver builds it).
///
/// A [VisibilityDetector] watches the child; the first time more than 10% of it
/// is on screen the entrance plays once (12px rise + fade, ~360ms). [delayMs]
/// staggers siblings in a row/grid. Honours reduced-motion
/// (`MediaQuery.disableAnimations`, wired to `prefers-reduced-motion` on web):
/// when set the child is returned as-is, fully visible, with no detector.
class RevealOnScroll extends StatefulWidget {
  const RevealOnScroll({super.key, required this.child, this.delayMs = 0});

  final Widget child;

  /// Stagger offset so items in a row cascade in.
  final int delayMs;

  @override
  State<RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<RevealOnScroll> {
  final Key _detectorKey = UniqueKey();
  bool _shown = false;

  void _onVisibility(VisibilityInfo info) {
    if (_shown || !mounted || info.visibleFraction <= 0.1) return;
    if (widget.delayMs > 0) {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) setState(() => _shown = true);
      });
    } else {
      setState(() => _shown = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;

    return VisibilityDetector(
      key: _detectorKey,
      onVisibilityChanged: _onVisibility,
      child: widget.child
          .animate(target: _shown ? 1 : 0)
          .fadeIn(duration: 340.ms, curve: Curves.easeOut)
          .moveY(
            begin: 12,
            end: 0,
            duration: 360.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }
}
