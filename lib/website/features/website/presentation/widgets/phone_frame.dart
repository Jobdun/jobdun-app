import 'package:flutter/material.dart';

import '../../../../../../core/design/colors.dart';

/// A phone bezel around an app screenshot. The bezel is a thin dark
/// surface with rounded corners, the screenshot inset, a faint orange
/// edge glow, and a small bottom-edge ambient darkening. No drop
/// shadows (banned by the design system).
///
/// Sizing is in *logical pixels* (no `.h` / `.w` from screenutil) so
/// the phone stays the same physical size across viewports. We use a
/// fixed 320×640 bezel at desktop, with `maxHeight` clamping it for
/// narrow mobile stacks.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({
    super.key,
    required this.asset,
    this.width = 320,
    this.maxHeight = 640,
    this.tilt = 0,
  });

  final String asset;
  final double width;
  final double maxHeight;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = width;
    final h = (width * 2).clamp(0.0, maxHeight); // 1:2 ratio

    return Transform.rotate(
      angle: tilt,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFF0A1220), // darker than c.surface
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: c.border, width: 1),
        ),
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
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
                      borderRadius: BorderRadius.circular(28),
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

