import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Motion style for [AnimatedEmptyGlyph]. Each empty state picks the one that
/// suits its icon (a search glyph pulses, a chat bubble bounces, a star
/// twinkles, etc.).
enum EmptyGlyphMotion { pulse, bounce, twinkle, float }

/// A gently-animated icon for empty states — replaces the static hero glyph with
/// a soft, looping micro-motion so a blank screen feels alive without shouting.
///
/// Theme-aware (defaults to `c.text3`, the muted empty-state colour) and
/// reduced-motion-aware: when the OS "reduce motion" setting is on it renders a
/// plain static icon. This is the code-built alternative to a Lottie loop — no
/// `.json` asset, full brand + theme control.
class AnimatedEmptyGlyph extends StatefulWidget {
  const AnimatedEmptyGlyph({
    super.key,
    required this.icon,
    this.motion = EmptyGlyphMotion.pulse,
    this.size = 40,
    this.color,
  });

  final IconData icon;
  final EmptyGlyphMotion motion;
  final double size;
  final Color? color;

  @override
  State<AnimatedEmptyGlyph> createState() => _AnimatedEmptyGlyphState();
}

class _AnimatedEmptyGlyphState extends State<AnimatedEmptyGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: switch (widget.motion) {
      EmptyGlyphMotion.pulse => const Duration(milliseconds: 1800),
      EmptyGlyphMotion.bounce => const Duration(milliseconds: 1500),
      EmptyGlyphMotion.twinkle => const Duration(milliseconds: 2200),
      EmptyGlyphMotion.float => const Duration(milliseconds: 2600),
    },
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // MediaQuery isn't available in initState. Only loop when motion is allowed.
    if (!MediaQuery.of(context).disableAnimations) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      widget.icon,
      size: widget.size,
      color: widget.color ?? context.c.text3,
    );

    // Reduced motion → plain static glyph at its neutral size/opacity.
    if (MediaQuery.of(context).disableAnimations) return icon;

    return AnimatedBuilder(
      animation: _c,
      child: icon,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value); // oscillates 0↔1
        return switch (widget.motion) {
          EmptyGlyphMotion.pulse => Opacity(
            opacity: 0.75 + 0.25 * t,
            child: Transform.scale(scale: 0.94 + 0.12 * t, child: child),
          ),
          EmptyGlyphMotion.bounce => Transform.translate(
            offset: Offset(0, -8 * t),
            child: child,
          ),
          EmptyGlyphMotion.twinkle => Opacity(
            opacity: 0.55 + 0.45 * t,
            child: Transform.scale(scale: 0.9 + 0.18 * t, child: child),
          ),
          EmptyGlyphMotion.float => Transform.translate(
            offset: Offset(0, -5 * t),
            child: Opacity(opacity: 0.85 + 0.15 * t, child: child),
          ),
        };
      },
    );
  }
}
