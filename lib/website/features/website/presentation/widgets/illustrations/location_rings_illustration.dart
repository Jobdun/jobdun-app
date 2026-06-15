import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../../../core/design/colors.dart';

/// Concentric rings + a central location pin, drawn with [CustomPainter].
/// No asset. Used in the marketing site as a vector illustration for
/// "near you" / "your suburb" ideas.
class LocationRingsIllustration extends StatelessWidget {
  const LocationRingsIllustration({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingsPainter(
          ringColor: c.action,
          pinColor: c.action,
          pinAccent: c.onAction,
          gridColor: c.border,
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({
    required this.ringColor,
    required this.pinColor,
    required this.pinAccent,
    required this.gridColor,
  });

  final Color ringColor;
  final Color pinColor;
  final Color pinAccent;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final maxR = math.min(w, h) / 2 - 2;

    for (var i = 0; i < 3; i++) {
      final r = maxR * (0.30 + i * 0.25);
      final paint = Paint()
        ..color = ringColor.withValues(alpha: 0.85 - i * 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.35)
      ..strokeWidth = 0.5;
    for (var x = 0.0; x <= w; x += w / 6) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (var y = 0.0; y <= h; y += h / 6) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    final pinRadius = maxR * 0.18;
    final pinCenter = Offset(cx, cy - pinRadius * 0.6);
    final pinFill = Paint()..color = pinColor;
    canvas.drawCircle(pinCenter, pinRadius, pinFill);

    final tail = Path()
      ..moveTo(pinCenter.dx - pinRadius * 0.7, pinCenter.dy + pinRadius * 0.7)
      ..lineTo(pinCenter.dx, pinCenter.dy + pinRadius * 2.0)
      ..lineTo(pinCenter.dx + pinRadius * 0.7, pinCenter.dy + pinRadius * 0.7)
      ..close();
    canvas.drawPath(tail, pinFill);

    canvas.drawCircle(pinCenter, pinRadius * 0.35, Paint()..color = pinAccent);
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) =>
      old.ringColor != ringColor ||
      old.pinColor != pinColor ||
      old.pinAccent != pinAccent ||
      old.gridColor != gridColor;
}
