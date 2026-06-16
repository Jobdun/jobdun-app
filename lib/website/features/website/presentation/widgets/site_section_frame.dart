import 'package:flutter/material.dart';

import '../../../../app/theme/breakpoints.dart';

/// Standard outer-frame for every section on the marketing site.
///
/// Composition: `Padding(horizontal: pad) > Center > ConstrainedBox(maxWidth: 1200) > child`.
///
/// Why a single widget:
///   - The whole site shares one horizontal rhythm. Per-section
///     padding tokens drift if every section picks its own. This
///     enforces the rhythm in one place.
///   - The max-width (1200) is wide enough for a 2-up phone layout
///     at desktop, narrow enough to keep the reading line under
///     75ch for editorial blocks.
///   - The padding scales: 96 on ≥1100px, 64 on 720–1100, 24 below.
///     The 96px matches the design system's `xxl` for "section-level
///     horizontal breathing room" (MASTER §149).
class SiteSectionFrame extends StatelessWidget {
  const SiteSectionFrame({
    super.key,
    required this.child,
    this.maxWidth = 1200,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final pad = w >= Bp.desktop
        ? 96.0
        : w >= Bp.tablet
        ? 64.0
        : 24.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: pad),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
