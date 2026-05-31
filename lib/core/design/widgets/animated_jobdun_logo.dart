import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../../app/theme/app_colors.dart';
import 'jobdun_logo.dart';
import 'jobdun_logo_path.dart';

/// Animation style for [AnimatedJobdunLogo].
///
/// - [forge]  — scale-in + fade + a white shimmer sweep + a spark burst at the
///              hammer head. Wraps the theme-aware [JobdunLogo], so it keeps the
///              dark-mark / light-badge behaviour. This is what ships to splash
///              + login.
/// - [strike] — the mark drops in from above with an overshoot bounce + an
///              impact spark. Also wraps [JobdunLogo] (theme-aware).
/// - [draw]   — the vector outline "draws itself" (PathMetrics trace) then the
///              fill fades in. Theme-aware like the others: orange J on
///              transparent in dark; white J on an orange badge in light.
enum JLogoAnim { forge, strike, draw }

/// One-shot animated presentation of the hammer-J brand mark. Plays once on
/// mount; honours `MediaQuery.disableAnimations` (jumps to the final static
/// logo). To replay, give it a fresh [Key] (the demo page swaps a `UniqueKey`).
class AnimatedJobdunLogo extends StatefulWidget {
  const AnimatedJobdunLogo({
    super.key,
    this.variant = JLogoAnim.forge,
    this.height = 64,
    this.autoPlay = true,
  });

  final JLogoAnim variant;
  final double height;

  /// When false the widget renders its final (settled) frame without animating.
  final bool autoPlay;

  @override
  State<AnimatedJobdunLogo> createState() => _AnimatedJobdunLogoState();
}

class _AnimatedJobdunLogoState extends State<AnimatedJobdunLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: switch (widget.variant) {
      JLogoAnim.forge => const Duration(milliseconds: 1100),
      JLogoAnim.strike => const Duration(milliseconds: 950),
      JLogoAnim.draw => const Duration(milliseconds: 1500),
    },
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // MediaQuery isn't available in initState — decide the entrance here.
    if (!widget.autoPlay || MediaQuery.of(context).disableAnimations) {
      _c.value = 1.0; // settled / reduced-motion
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.variant) {
      JLogoAnim.forge => _ForgeVariant(controller: _c, height: widget.height),
      JLogoAnim.strike => _StrikeVariant(controller: _c, height: widget.height),
      JLogoAnim.draw => _DrawVariant(controller: _c, height: widget.height),
    };
  }
}

/// Spark/accent colour that stays visible on whatever the logo sits on: the
/// brand orange on the dark canvas, dark slate (`onAction`) on the light badge
/// + page — an orange spark would vanish on the orange light-mode badge.
Color _sparkColor(BuildContext context) {
  final c = context.c;
  return Theme.of(context).brightness == Brightness.dark
      ? c.action
      : c.onAction;
}

// ── forge ──────────────────────────────────────────────────────────────────────

class _ForgeVariant extends StatelessWidget {
  const _ForgeVariant({required this.controller, required this.height});

  final AnimationController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    final sparkColor = _sparkColor(context);
    return AnimatedBuilder(
      animation: controller,
      // The logo is built once and reused across frames.
      child: JobdunLogo(variant: LogoVariant.mark, height: height),
      builder: (context, child) {
        final t = controller.value;
        final enter = Curves.easeOutCubic.transform((t / 0.55).clamp(0.0, 1.0));
        final sweep = ((t - 0.35) / 0.5).clamp(0.0, 1.0); // shimmer window
        final spark = ((t - 0.55) / 0.45).clamp(0.0, 1.0); // spark window

        Widget mark = child!;
        if (sweep > 0.0 && sweep < 1.0) {
          mark = ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) {
              final band = -0.2 + sweep * 1.4; // travels off both edges
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: const [
                  Colors.transparent,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [
                  (band - 0.15).clamp(0.0, 1.0),
                  band.clamp(0.0, 1.0),
                  (band + 0.15).clamp(0.0, 1.0),
                ],
              ).createShader(rect);
            },
            child: mark,
          );
        }

        return Opacity(
          opacity: enter,
          child: Transform.scale(
            scale: 1.15 - 0.15 * enter,
            child: Stack(
              alignment: Alignment.center,
              children: [
                mark,
                if (spark > 0.0 && spark < 1.0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _SparkPainter(
                          progress: spark,
                          color: sparkColor,
                          focal: const Alignment(0.28, -0.34),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── strike ─────────────────────────────────────────────────────────────────────

class _StrikeVariant extends StatelessWidget {
  const _StrikeVariant({required this.controller, required this.height});

  final AnimationController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    final sparkColor = _sparkColor(context);
    return AnimatedBuilder(
      animation: controller,
      child: JobdunLogo(variant: LogoVariant.mark, height: height),
      builder: (context, child) {
        final t = controller.value;
        // easeOutBack overshoots near the end → reads as a landing bounce.
        final fall = Curves.easeOutBack.transform((t / 0.6).clamp(0.0, 1.0));
        final dy = (1.0 - fall) * -0.55 * height;
        final opacity = (t / 0.2).clamp(0.0, 1.0);
        final spark = ((t - 0.5) / 0.5).clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Stack(
              alignment: Alignment.center,
              children: [
                child!,
                if (spark > 0.0 && spark < 1.0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _SparkPainter(
                          progress: spark,
                          color: sparkColor,
                          focal: const Alignment(0.28, -0.34),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── draw / trace ─────────────────────────────────────────────────────────────

class _DrawVariant extends StatelessWidget {
  const _DrawVariant({required this.controller, required this.height});

  final AnimationController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Mirror the static mark: dark = orange J on transparent; light = white J
    // on an orange rounded-square badge.
    final ink = isDark ? c.action : Colors.white;
    final badge = isDark ? null : c.action;
    return SizedBox(
      width: height,
      height: height,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => CustomPaint(
          size: Size(height, height),
          painter: _DrawTracePainter(
            progress: controller.value,
            ink: ink,
            badge: badge,
          ),
        ),
      ),
    );
  }
}

// ── painters ─────────────────────────────────────────────────────────────────

/// Traces the hammer-J outline (PathMetrics) for `progress` 0→0.75, then fades
/// the fill in for 0.75→1.0. Theme-aware: in light mode it draws an orange
/// rounded-square [badge] behind a white [ink] J (mirroring mark-jobdun-light);
/// in dark mode [badge] is null and [ink] is the brand orange on transparent.
class _DrawTracePainter extends CustomPainter {
  _DrawTracePainter({required this.progress, required this.ink, this.badge});

  final double progress;
  final Color ink;
  final Color? badge;

  // Parsed once. even-odd matches the SVG's fill-rule so the negative-space
  // cuts render correctly.
  static final Path _base = parseSvgPathData(kHammerJPathData)
    ..fillType = PathFillType.evenOdd;

  @override
  void paint(Canvas canvas, Size size) {
    // Light-mode badge — orange rounded square behind the white J, fading in
    // fast; 18.75% corner radius matches the static light mark.
    final badgeColor = badge;
    if (badgeColor != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(size.width * 0.1875),
        ),
        Paint()
          ..color = badgeColor.withValues(
            alpha: (progress / 0.2).clamp(0.0, 1.0),
          ),
      );
    }

    final s = size.width / kHammerJViewBox.width;
    final drawP = (progress / 0.75).clamp(0.0, 1.0);
    final fillP = ((progress - 0.75) / 0.25).clamp(0.0, 1.0);

    canvas.save();
    canvas.scale(s);

    if (drawP > 0.0 && fillP < 1.0) {
      final traced = Path();
      for (final m in _base.computeMetrics()) {
        traced.addPath(m.extractPath(0, m.length * drawP), Offset.zero);
      }
      canvas.drawPath(
        traced,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth =
              7 /
              s // ~7 logical px at any render size
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = ink,
      );
    }

    if (fillP > 0.0) {
      canvas.drawPath(
        _base,
        Paint()
          ..style = PaintingStyle.fill
          ..color = ink.withValues(alpha: fillP),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DrawTracePainter old) =>
      old.progress != progress || old.ink != ink || old.badge != badge;
}

/// A spark burst — an expanding ring + radiating rays at [focal], fading as it
/// grows. Driven by `progress` 0→1.
class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.progress,
    required this.color,
    this.focal = Alignment.center,
  });

  final double progress;
  final Color color;
  final Alignment focal;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Curves.easeOut.transform(progress);
    final center = focal.alongSize(size);
    final maxR = size.shortestSide * 0.5;
    final alpha = (1.0 - p).clamp(0.0, 1.0);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: alpha);

    canvas.drawCircle(center, maxR * p, paint..strokeWidth = 2.0);

    final inner = maxR * (0.2 + 0.45 * p);
    final outer = inner + maxR * 0.22 * (1.0 - p * 0.6);
    paint.strokeWidth = 2.5;
    const rays = 8;
    for (var i = 0; i < rays; i++) {
      final a = (i / rays) * 2 * math.pi + math.pi / rays;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(center + dir * inner, center + dir * outer, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.progress != progress;
}
