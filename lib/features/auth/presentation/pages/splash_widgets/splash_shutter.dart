import 'package:flutter/material.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/design/widgets/jobdun_logo.dart';

/// Cold-start brand animation — the "Split Shutter" of the three Figma loading
/// frames (`JobDun-Screens`, nodes 17:5059 / 14:5022 / 14:4068), collapsed into
/// one continuous move.
///
/// Three beats over 1.8s:
///  1. hold — the orange field fills the screen, mark in white, dead centre.
///     This is what the native launch screen already paints, so the handoff
///     from the OS splash to Flutter is seamless (no flash, no jump).
///  2. split — the field parts along the mark's waist and the two halves
///     retract. The mark holds still while the edges sweep past it, so it reads
///     two-tone for a beat: white inside the departing panels, brand orange on
///     the ground behind them.
///  3. settle — the mark slides left by exactly half the lockup's spare width
///     and the wordmark opens outward from its centre, landing on Figma frame 3.
///
/// Theme-aware by design: the ground the shutter reveals is `c.background`, so
/// light lands on the near-white of the Figma frames and dark lands on the
/// brand slate. [JobdunLogo] already swaps the navy wordmark for `text1` to
/// match, which is why this widget never names a wordmark colour.
///
/// Honours `MediaQuery.disableAnimations` — reduced motion jumps straight to
/// the settled lockup and reports completion on the next frame.
class SplashShutter extends StatefulWidget {
  const SplashShutter({super.key, this.onSettled, this.autoPlay = true});

  /// Fired once the mark and wordmark have landed. The splash page uses this
  /// to hand over to the router rather than racing a bare timer.
  final VoidCallback? onSettled;

  /// When false the widget paints its settled frame without animating.
  final bool autoPlay;

  @override
  State<SplashShutter> createState() => _SplashShutterState();
}

// ── Figma geometry, in the frame's own px (393 x 852). Every dimension below
// is derived from `_markH`, so the whole lockup scales from one number.
//
// Scaling is taken from the box this actually paints into rather than
// ScreenUtil: the splash is full-bleed, so `height / 852` reproduces the frame
// exactly on any surface, and the geometry stays verifiable in a widget test
// (ScreenUtil resolves against the raw test window, not the pumped surface).
const double _frameH = 852;
const double _markH = 59;
const double _markW = 40.0866;
const double _lockW = 249; // mark + gap + wordmark
const double _wordW = 203.302;
const double _wordH = 29.5866;

/// The wordmark's optical centre sits 4.22px below the mark's — the designer
/// nudged it down against the glyph's visual mass. Kept rather than "corrected".
const double _wordDy = 4.22;

// Beat boundaries as fractions of the 1.8s run.
const double _shutFrom = 600 / 1800;
const double _shutTo = 1160 / 1800;
const double _slideFrom = 1360 / 1800;
const double _wordTo = 1760 / 1800;

class _SplashShutterState extends State<SplashShutter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  late final Animation<double> _shut = CurvedAnimation(
    parent: _c,
    curve: const Interval(_shutFrom, _shutTo, curve: Cubic(.76, 0, .24, 1)),
  );
  late final Animation<double> _slide = CurvedAnimation(
    parent: _c,
    curve: const Interval(_slideFrom, 1, curve: Cubic(.72, 0, .22, 1)),
  );
  late final Animation<double> _open = CurvedAnimation(
    parent: _c,
    curve: const Interval(_slideFrom, _wordTo, curve: Cubic(.66, 0, .2, 1)),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // MediaQuery isn't readable in initState, so the entrance is decided here.
    final reduced = MediaQuery.of(context).disableAnimations;
    if (!widget.autoPlay || reduced) {
      _c.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _settle());
    } else {
      _c.forward().whenComplete(_settle);
    }
  }

  void _settle() {
    if (mounted) widget.onSettled?.call();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return ColoredBox(
      color: c.background,
      child: LayoutBuilder(
        builder: (context, box) {
          final unit = box.maxHeight / _frameH; // Figma px -> logical px
          final markH = _markH * unit;
          final markW = _markW * unit;

          final cx = box.maxWidth / 2;
          final splitY = box.maxHeight / 2; // the mark's waist
          final markTop = splitY - markH / 2;
          final markLeft = cx - markW / 2; // beats 1-2: dead centre
          final travel = (_lockW - _markW) / 2 * unit; // 104.46px at 1:1

          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Stack(
              clipBehavior: Clip.none,
              children: [
                _SettledLockup(
                  unit: unit,
                  markLeft: markLeft,
                  markTop: markTop,
                  travel: travel,
                  slide: _slide.value,
                  open: _open.value,
                ),
                // The shutter paints over the settled state until it clears.
                _ShutterPanel(
                  half: _Half.top,
                  fill: c.action,
                  progress: _shut.value,
                  splitY: splitY,
                  height: box.maxHeight,
                  markLeft: markLeft,
                  markTop: markTop,
                  markH: markH,
                ),
                _ShutterPanel(
                  half: _Half.bottom,
                  fill: c.action,
                  progress: _shut.value,
                  splitY: splitY,
                  height: box.maxHeight,
                  markLeft: markLeft,
                  markTop: markTop,
                  markH: markH,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Beat 3 — the mark travelling left with the wordmark opening beside it.
/// Painted underneath the shutter, so it is simply revealed rather than
/// cross-faded in.
class _SettledLockup extends StatelessWidget {
  const _SettledLockup({
    required this.unit,
    required this.markLeft,
    required this.markTop,
    required this.travel,
    required this.slide,
    required this.open,
  });

  final double unit, markLeft, markTop, travel, slide, open;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final markH = _markH * unit;
    final markW = _markW * unit;
    final wordH = _wordH * unit;

    // The wordmark's left edge butts against the mark's settled right edge
    // plus the lockup's internal gap; anchor on its centre so it can open
    // symmetrically without the box shifting.
    final settledMarkLeft = markLeft - travel;
    final wordCentreX =
        settledMarkLeft +
        markW +
        (_lockW - _markW - _wordW) * unit +
        _wordW * unit / 2;
    final wordCentreY = markTop + markH / 2 + _wordDy * unit;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: wordCentreX,
          top: wordCentreY - wordH / 2,
          child: FractionalTranslation(
            translation: const Offset(-0.5, 0),
            child: ClipRect(
              child: Align(
                alignment: Alignment.center,
                // A hair above zero: a 0-width Align collapses the clip and
                // Flutter asserts on the degenerate layer.
                widthFactor: open.clamp(0.0001, 1.0),
                child: JobdunLogo(variant: LogoVariant.wordmark, height: wordH),
              ),
            ),
          ),
        ),
        Positioned(
          left: markLeft,
          top: markTop,
          child: Transform.translate(
            offset: Offset(-travel * slide, 0),
            child: JobdunLogo(
              variant: LogoVariant.mark,
              height: markH,
              color: c.action,
            ),
          ),
        ),
      ],
    );
  }
}

enum _Half { top, bottom }

/// One half of the retracting orange field.
///
/// The panel translates off-screen while the white mark inside it translates
/// back by the same amount, so the glyph stays pinned to the screen while the
/// panel's edge sweeps across it. That counter-move is what produces the
/// two-tone moment — without it the mark would ride away with the panel.
class _ShutterPanel extends StatelessWidget {
  const _ShutterPanel({
    required this.half,
    required this.fill,
    required this.progress,
    required this.splitY,
    required this.height,
    required this.markLeft,
    required this.markTop,
    required this.markH,
  });

  final _Half half;
  final Color fill;
  final double progress, splitY, height, markLeft, markTop, markH;

  @override
  Widget build(BuildContext context) {
    final isTop = half == _Half.top;
    final extent = isTop ? splitY : height - splitY;
    final shift = extent * progress;

    return Positioned(
      left: 0,
      right: 0,
      top: isTop ? 0 : splitY,
      height: extent,
      child: Transform.translate(
        offset: Offset(0, isTop ? -shift : shift),
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: ColoredBox(color: fill)),
              Positioned(
                left: markLeft,
                // The bottom panel's local origin is the split line, so the
                // mark's top sits above it and gets clipped to its lower half.
                top: isTop ? markTop : markTop - splitY,
                child: Transform.translate(
                  offset: Offset(0, isTop ? shift : -shift),
                  child: JobdunLogo(
                    variant: LogoVariant.mark,
                    height: markH,
                    // The mark reverses out of the orange field, matching the
                    // trademark lockup and the native launch screen.
                    color: Colors.white, // intentional: on the orange field
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
