import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/design/colors.dart';

// Hero visual for slide 2 — stylized, abstract "your area" map. Pairs with
// the suburb chips below so the slide carries the same visual weight as
// the photo-driven slides 1 + 3 without resorting to a static map image
// that would undercut the personalisation wow.
//
// Treatment matches FtueHeroPhoto: 16:11 aspect ratio, AppRadius.card,
// soft navy-tinted shadow, hi-vis corner accent. Inside: a faint grid
// pattern reads as "map", an orange "you are here" pin sits dead-centre,
// and smaller surface-tone pins are scattered around it to represent the
// near-by suburb cluster.
class FtueMapHero extends StatelessWidget {
  const FtueMapHero({super.key, this.pinCount = 4});

  /// Number of secondary (suburb) pins around the centre marker. Defaults
  /// to 4 — enough density to read as "a cluster", not so many it gets
  /// noisy at the 16:11 aspect.
  final int pinCount;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AspectRatio(
      aspectRatio: 16 / 11,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(color: c.border),
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
              // Grid pattern — thin border-coloured lines so the surface
              // reads as a map and not just a tinted card.
              CustomPaint(
                painter: _MapGridPainter(
                  gridColor: c.border,
                  ringColor: c.action.withValues(alpha: 0.18),
                ),
              ),
              // Surrounding suburb pins — secondary visual weight.
              for (final pin in _suburbPinOffsets(pinCount))
                Align(
                  alignment: pin,
                  child: Icon(Iconsax.location5, size: 18.r, color: c.text2),
                ),
              // "You are here" centre pin — orange, larger, with a soft
              // halo ring drawn underneath by the grid painter above.
              Center(
                child: Icon(Iconsax.location5, size: 36.r, color: c.action),
              ),
              // Hi-vis corner accent — matches FtueHeroPhoto so all three
              // slide visuals share the safety-stripe motif.
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
  }

  // Symmetric-ish offsets so the cluster reads as "around the centre" but
  // never tiled. Tuned by eye for the 16:11 aspect at typical phone widths.
  static List<Alignment> _suburbPinOffsets(int count) {
    const positions = [
      Alignment(-0.55, -0.45),
      Alignment(0.55, -0.30),
      Alignment(-0.40, 0.50),
      Alignment(0.50, 0.40),
      Alignment(-0.75, 0.15),
      Alignment(0.75, 0.05),
    ];
    return positions.take(count).toList();
  }
}

class _MapGridPainter extends CustomPainter {
  _MapGridPainter({required this.gridColor, required this.ringColor});

  final Color gridColor;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor.withValues(alpha: 0.55)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Vertical lines — six columns at 1/6 intervals.
    const cols = 6;
    for (var i = 1; i < cols; i++) {
      final x = size.width * i / cols;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    // Horizontal lines — four rows.
    const rows = 4;
    for (var i = 1; i < rows; i++) {
      final y = size.height * i / rows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Concentric range rings centred on the "you are here" pin. Reads as
    // "jobs within X kilometres" without needing a label.
    final centre = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()
      ..color = ringColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final maxRadius = math.min(size.width, size.height) * 0.42;
    for (final t in const [0.35, 0.65, 1.0]) {
      canvas.drawCircle(centre, maxRadius * t, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter old) =>
      old.gridColor != gridColor || old.ringColor != ringColor;
}
