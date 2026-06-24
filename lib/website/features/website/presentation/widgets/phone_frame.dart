import 'package:flutter/material.dart';

import '../../../../../../core/design/colors.dart';

/// A phone bezel around an app screenshot. The bezel is a thin dark
/// surface with rounded corners, the screenshot inset, a faint orange
/// edge glow, and a small bottom-edge ambient darkening. No drop
/// shadows (banned by the design system).
///
/// Aspect ratio is **9:19.5** (≈0.46). A modern flagship phone
/// (iPhone Pro Max / Galaxy S24 Ultra). Width defaults to 320, so
/// the bezel renders at 320×~696 logical pixels. Pass a smaller
/// [width] for mobile stacks where the carousel needs to be
/// shorter, or use the [aspectRatio] param to override.
///
/// Sizing is in *logical pixels* (no `.h` / `.w` from screenutil) so
/// the phone stays the same physical size across viewports. We
/// pass [maxHeight] as a clamp to prevent the rendered phone from
/// being absurdly tall in tall viewport test pages.
///
/// Set [peekFromTop] (0.0–1.0) to crop the screenshot so only the
/// top slice is visible. Used by the trust-safety proof block to
/// show only the top portion of an in-app screenshot: the phone
/// renders large and only the top 30% of the screen is visible, so
/// the device reads as if it's rising from below the surface. 0.30
/// shows the top third of the source screenshot. 1.0 (default)
/// shows the whole screenshot.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({
    super.key,
    required this.asset,
    this.semanticLabel,
    this.width = 320,
    this.maxHeight = 800,
    this.tilt = 0,
    this.peekFromTop = 1.0,
  });

  final String asset;

  /// Alt text for the screenshot (WCAG 1.1.1). When null the frame is marked
  /// decorative so screen readers skip it instead of announcing a filename.
  final String? semanticLabel;
  final double width;
  final double maxHeight;
  final double tilt;

  /// Fraction of the source screenshot height to show, anchored at
  /// the top. 1.0 (default) shows the whole screenshot. 0.30 shows
  /// the top 30%, with the bottom 70% cropped. Only honoured if
  /// `peekFromTop` is in the range (0.0, 1.0].
  final double peekFromTop;

  // Modern flagship phone aspect: 9:19.5 (≈ 0.46).
  static const double _aspect = 9 / 19.5;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = width;
    final peeking = peekFromTop > 0.0 && peekFromTop < 1.0;

    // Peek mode: render only the visible top slice. No full-height
    // bezel, no padding wrapper — the device's bottom edge is the
    // clipped edge of the screenshot. Top corners are rounded; bottom
    // is square. Sized to the natural visible height (= width ×
    // (9:19.5 aspect) × peek fraction).
    if (peeking) {
      return Transform.rotate(
        angle: tilt,
        child: _PeekContent(
          asset: asset,
          semanticLabel: semanticLabel,
          fraction: peekFromTop,
        ),
      );
    }

    final h = (w / _aspect).clamp(0.0, maxHeight);
    return Transform.rotate(
      angle: tilt,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFF0A1220), // darker than c.surface
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: c.border, width: 1),
        ),
        padding: const EdgeInsets.all(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: _FullContent(asset: asset, semanticLabel: semanticLabel, c: c),
        ),
      ),
    );
  }
}

class _FullContent extends StatelessWidget {
  const _FullContent({
    required this.asset,
    required this.semanticLabel,
    required this.c,
  });
  final String asset;
  final String? semanticLabel;
  final JColors c;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            semanticLabel: semanticLabel,
            excludeFromSemantics: semanticLabel == null,
          ),
        ),
        // Faint orange right-edge glow, sits over the screenshot
        // to suggest light coming from the right. 10% alpha,
        // no shadow required.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    c.action.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.18],
                ),
              ),
            ),
          ),
        ),
        // Ambient bottom darkening, also banned as a true
        // shadow, so this is a single linear-gradient darkening
        // at the bottom edge.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF000000).withValues(alpha: 0.20),
                  ],
                  stops: const [0.0, 0.75, 1.0],
                ),
                borderRadius: BorderRadius.circular(32),
              ),
            ),
          ),
        ),
        // Top-edge specular highlight: a thin orange line that
        // catches the eye, reads as a "premium device" detail
        // and ties back to the brand. ~2% alpha so it never
        // reads as a border.
        Positioned(
          top: 6,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    c.action.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows only the top [fraction] of the source screenshot. Used for
/// the trust-safety proof block so the phone reads as a device
/// rising up from below the surface — only the top portion of the
/// screen is visible, and the bezel ends at the cropped edge so the
/// part that isn't shown doesn't render.
///
/// Implementation: render a SizedBox sized to the visible top slice
/// of the screenshot (no full-height bezel). The container is the
/// visible slice only — the screenshot's natural aspect ratio,
/// clipped at the bottom. Top corners are rounded (matches the
/// phone's full bezel). Right-edge orange glow + top-edge specular
/// highlight stay; bottom darkening is dropped since the bottom
/// edge of the visible slice is the bezel's new "edge".
class _PeekContent extends StatelessWidget {
  const _PeekContent({
    required this.asset,
    required this.semanticLabel,
    required this.fraction,
  });
  final String asset;
  final String? semanticLabel;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bezelW = constraints.maxWidth;
        if (bezelW <= 0) return const SizedBox.shrink();
        // The screenshot has the phone's intrinsic 9:19.5 aspect
        // (1080:2340). At a width of `bezelW`, its natural height is
        // `bezelW / _aspect`. We show only the top `fraction` of that
        // height, so the visible card is exactly that height.
        final sourceH = bezelW / (9 / 19.5);
        final visibleH = sourceH * fraction;
        return SizedBox(
          width: bezelW,
          height: visibleH,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                // The screenshot, anchored at the top. The full image
                // is laid out at sourceH height but the parent SizedBox
                // clips the bottom (1 - fraction) via the ClipRRect
                // already; we still use OverflowBox to lay out the
                // full image at its natural height without rescaling,
                // so the screenshot's top 32% renders at its source
                // resolution.
                OverflowBox(
                  minHeight: sourceH,
                  maxHeight: sourceH,
                  alignment: Alignment.topCenter,
                  child: Image.asset(
                    asset,
                    fit: BoxFit.cover,
                    width: bezelW,
                    height: sourceH,
                    alignment: Alignment.topCenter,
                    semanticLabel: semanticLabel,
                    excludeFromSemantics: semanticLabel == null,
                  ),
                ),
                // Right-edge orange glow (matches the full view's
                // accent). Light coming from the right.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          c.action.withValues(alpha: 0.10),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.18],
                      ),
                    ),
                  ),
                ),
                // Top-edge specular highlight. ~2% alpha, thin line
                // — reads as a "premium device" detail.
                Positioned(
                  top: 6,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            c.action.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
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
