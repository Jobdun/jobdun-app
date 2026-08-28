import 'package:flutter/material.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/services/ftue_analytics.dart';

/// Full-bleed hero image for one onboarding slide.
///
/// Figma `JobDun-Screens` → Onboard (node 17:5084) builds each slide's visual
/// from two layers — a peach illustration at 70% opacity under a cut-out photo
/// of a tradie. Both are baked into one transparent WebP at build time (see
/// `assets/images/ftue/README.md`), so this widget only has to place the image
/// and fade its bottom edge into the page.
///
/// The scrim runs `c.background` transparent → opaque across the bottom 41% of
/// the box, matching the Figma gradient stop for stop. Reading the token rather
/// than a literal white is what keeps the headline that sits on top of it
/// legible in dark mode too — and lets the hero meet the role sheet below
/// without a seam.
///
/// A missing asset never collapses the slide: [Image.errorBuilder] falls back
/// to the page background and reports `ftue.image_load_failed`.
class FtueHero extends StatefulWidget {
  const FtueHero({
    super.key,
    required this.assetPath,
    required this.slideIndex,
    this.semanticLabel,
  });

  final String assetPath;

  /// Only used for the `ftue.image_load_failed` payload — tells the dashboard
  /// which slide is missing its hero.
  final int slideIndex;

  final String? semanticLabel;

  /// Fraction of the hero's height the bottom scrim covers (234 / 567 in the
  /// Figma frame).
  static const _scrimStart = 1 - 234 / 567;

  @override
  State<FtueHero> createState() => _FtueHeroState();
}

class _FtueHeroState extends State<FtueHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  bool _loadFailureReported = false;
  bool _entranceStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // Settles *down* to 1.0, so the image covers the box for the whole run —
    // scaling up from 1.0 would expose the edges mid-animation.
    _scale = Tween<double>(
      begin: 1.03,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.5, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    // Honour the OS "reduce motion" setting — jump to the final state instead
    // of running the entrance. MediaQuery isn't available in initState, so the
    // decision lives here.
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reportLoadFailure() {
    if (_loadFailureReported) return;
    _loadFailureReported = true;
    FtueAnalytics.imageLoadFailed(
      slideIndex: widget.slideIndex,
      assetPath: widget.assetPath,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (_, child) => Opacity(
              opacity: _opacity.value,
              child: Transform.scale(scale: _scale.value, child: child),
            ),
            child: Image.asset(
              widget.assetPath,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              semanticLabel: widget.semanticLabel,
              errorBuilder: (_, _, _) {
                // Post-frame so we don't mutate state mid-build. Renders the
                // page background regardless, so the layout never collapses.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _reportLoadFailure();
                });
                return ColoredBox(color: c.background);
              },
            ),
          ),
          // Bottom scrim — carries the photo into the page so the headline and
          // the role sheet below read as one surface.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, FtueHero._scrimStart, 0.673, 0.762, 1.0],
                  colors: [
                    c.background.withValues(alpha: 0),
                    c.background.withValues(alpha: 0),
                    c.background.withValues(alpha: 0.70),
                    c.background.withValues(alpha: 0.916),
                    c.background,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
