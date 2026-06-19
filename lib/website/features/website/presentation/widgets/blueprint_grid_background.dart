import 'package:flutter/material.dart';

import '../../../../../../core/design/colors.dart';

/// A blueprint-paper style background grid, drawn with [CustomPainter].
///
/// The grid is *faint enough* (4% alpha) that it never reads as a
/// "decoration" competing with the content. It reads as the subtle
/// graph-paper texture of a job-site clipboard: the kind of
/// thing you'd only notice if you stopped to look.
///
/// Why this works for Jobdun:
///   - Construction plans (architectural drawings) are drawn on
///     blue grid paper. The visual language is in the audience's
///     muscle memory.
///   - The grid is mathematical (50px square), regular, and
///     rhythmic. It doesn't fight the typography.
///   - It's flat colour, no gradient, no glow, no glass. Banned
///     list passes.
///
/// Optional [axis] let callers skew the grid (e.g. on the BuiltFor
/// editorial block we can run the lines at a 5° angle to read as a
/// "blueprint / section cut" rather than a notebook page).
class BlueprintGridBackground extends StatelessWidget {
  const BlueprintGridBackground({
    super.key,
    this.child,
    this.spacing = 56,
    this.color,
    this.strokeWidth = 0.5,
    this.minor = true,
  });

  final Widget? child;
  final double spacing;
  final Color? color;
  final double strokeWidth;
  final bool minor;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final paint = Paint()
      ..color = (color ?? c.border).withValues(alpha: minor ? 0.18 : 0.32)
      ..strokeWidth = strokeWidth;
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(spacing: spacing, linePaint: paint),
            // The grid sits behind everything; do not absorb hits.
            child: const SizedBox.expand(),
          ),
        ),
        ?child,
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.spacing, required this.linePaint});

  final double spacing;
  final Paint linePaint;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    for (var x = 0.0; x <= w; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), linePaint);
    }
    for (var y = 0.0; y <= h; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(w, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.spacing != spacing || old.linePaint != linePaint;
}
