import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/ftue_analytics.dart';

/// Hero photo container for FTUE slides 1 and 3. Sits at the top of each
/// slide (not full-bleed background) so the stencil headline stays the
/// brand hero and the photograph supports it — overlay-on-photo legibility
/// gets risky on small screens.
///
/// Treatment per the wow-pass brief:
///   • 16:11 AspectRatio
///   • 8px (AppRadius.card) corner radius — matches surface cards
///   • Bottom-half navy gradient (transparent → navy@30% alpha) for weight
///   • Hi-vis 4px corner stripe bottom-left, tying to the safety-stripe motif
///   • Soft navy-tinted drop shadow (Aggressive-Flat keeps it understated)
///   • Scale 1.05 → 1.0 + fade-in over 600ms easeOutCubic on mount
///   • errorBuilder degrades to a navy placeholder — missing-asset never
///     crashes the slide, only fires ftue.image_load_failed
class FtueHeroPhoto extends StatefulWidget {
  const FtueHeroPhoto({
    super.key,
    required this.assetPath,
    required this.slideIndex,
    this.semanticLabel,
  });

  final String assetPath;

  /// Used only for the ftue.image_load_failed analytics payload — tells the
  /// dashboard which slide is missing its hero so Ken's image-drop queue
  /// can be prioritised.
  final int slideIndex;

  final String? semanticLabel;

  @override
  State<FtueHeroPhoto> createState() => _FtueHeroPhotoState();
}

class _FtueHeroPhotoState extends State<FtueHeroPhoto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  bool _loadFailureReported = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = Tween<double>(
      begin: 1.05,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
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

    final tile = AspectRatio(
      aspectRatio: 16 / 11,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          boxShadow: [
            BoxShadow(
              color: c.background.withValues(alpha: 0.45),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                widget.assetPath,
                fit: BoxFit.cover,
                semanticLabel: widget.semanticLabel,
                errorBuilder: (_, _, _) {
                  // Fire-and-forget — post-frame so we don't mutate state
                  // mid-build. Renders the navy placeholder regardless so
                  // the slide layout never collapses.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _reportLoadFailure();
                  });
                  return ColoredBox(color: c.background);
                },
              ),
              // Bottom-half navy gradient — adds tactile weight without
              // veiling the photo's subject.
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        c.background.withValues(alpha: 0),
                        c.background.withValues(alpha: 0.3),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // Hi-vis orange corner accent — ties the photo into the
              // safety-stripe motif on the page indicator.
              Positioned(
                left: 0,
                bottom: 0,
                child: Container(width: 32.w, height: 4.h, color: c.action),
              ),
            ],
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(scale: _scale.value, child: tile),
      ),
    );
  }
}
