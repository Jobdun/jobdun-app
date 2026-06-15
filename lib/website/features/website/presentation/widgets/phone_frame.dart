import 'package:flutter/material.dart';

import '../../../../../../core/design/colors.dart';

/// A phone bezel around an app screenshot. The bezel is a thin dark
/// surface with rounded corners, the screenshot inset, a faint orange
/// edge glow, and a small bottom-edge ambient darkening. No drop
/// shadows (banned by the design system).
///
/// Aspect ratio is **9:19.5** (≈0.46) — a modern flagship phone
/// (iPhone Pro Max / Galaxy S24 Ultra). Width defaults to 320, so
/// the bezel renders at 320×~696 logical pixels. Pass a smaller
/// [width] for mobile stacks where the carousel needs to be
/// shorter, or use the [aspectRatio] param to override.
///
/// Sizing is in *logical pixels* (no `.h` / `.w` from screenutil) so
/// the phone stays the same physical size across viewports. We
/// pass [maxHeight] as a clamp to prevent the rendered phone from
/// being absurdly tall in tall viewport test pages.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({
    super.key,
    required this.asset,
    this.width = 320,
    this.maxHeight = 800,
    this.tilt = 0,
  });

  final String asset;
  final double width;
  final double maxHeight;
  final double tilt;

  // Modern flagship phone aspect — 9:19.5 (≈ 0.46).
  static const double _aspect = 9 / 19.5;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = width;
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
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
              // Faint orange right-edge glow — sits over the screenshot
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
              // Ambient bottom darkening — also banned as a true
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
              // Top-edge specular highlight — a thin orange line that
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
          ),
        ),
      ),
    );
  }
}
