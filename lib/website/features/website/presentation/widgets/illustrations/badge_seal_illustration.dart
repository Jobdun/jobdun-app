import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../../../core/design/colors.dart';

/// Circular "verified seal": a dashed outer ring + a solid inner ring +
/// a centered check-mark. Drawn with [CustomPainter], no asset. Used on
/// the marketing site as a vector for verification / accreditation.
class BadgeSealIllustration extends StatelessWidget {
  const BadgeSealIllustration({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _SealPainter(
          ringColor: c.action,
          checkColor: c.action,
          dotColor: c.borderStrong,
        ),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  _SealPainter({
    required this.ringColor,
    required this.checkColor,
    required this.dotColor,
  });

  final Color ringColor;
  final Color checkColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;

    final dashPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    _drawDashedCircle(canvas, c, r, dashPaint, dashCount: 24, dashLength: 6);

    final innerPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(c, r * 0.78, innerPaint);

    final checkPath = Path()
      ..moveTo(c.dx - r * 0.30, c.dy)
      ..lineTo(c.dx - r * 0.05, c.dy + r * 0.25)
      ..lineTo(c.dx + r * 0.40, c.dy - r * 0.20);
    final checkPaint = Paint()
      ..color = checkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(checkPath, checkPaint);

    final dotPaint = Paint()..color = dotColor;
    for (final angleDeg in const [0.0, 90.0, 180.0, 270.0]) {
      final theta = angleDeg * math.pi / 180;
      final dx = math.cos(theta) * r * 0.78;
      final dy = math.sin(theta) * r * 0.78;
      canvas.drawCircle(c.translate(dx, dy), 2, dotPaint);
    }
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    required int dashCount,
    required double dashLength,
  }) {
    final circumference = 2 * math.pi * radius;
    final dashArc = (dashLength / circumference) * 2 * math.pi;
    for (var i = 0; i < dashCount; i++) {
      final start = (i / dashCount) * 2 * math.pi;
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, start, dashArc, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SealPainter old) =>
      old.ringColor != ringColor ||
      old.checkColor != checkColor ||
      old.dotColor != dotColor;
}
