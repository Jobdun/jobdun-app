import 'package:flutter/material.dart';

import '../../../../../../core/design/colors.dart';

/// Stylised hammer — a thick horizontal head + a vertical handle. Drawn
/// with [CustomPainter], no asset. Used on the marketing site as the
/// "for tradies / on the tools" vector.
class HammerMarkIllustration extends StatelessWidget {
  const HammerMarkIllustration({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _HammerPainter(headColor: c.action, handleColor: c.text1),
      ),
    );
  }
}

class _HammerPainter extends CustomPainter {
  _HammerPainter({required this.headColor, required this.handleColor});

  final Color headColor;
  final Color handleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final handleWidth = w * 0.10;
    final handleHeight = h * 0.85;
    final handleRect = Rect.fromLTWH(
      w * 0.30,
      h * 0.10,
      handleWidth,
      handleHeight,
    );
    final handleRRect = RRect.fromRectAndRadius(
      handleRect,
      Radius.circular(handleWidth / 2),
    );
    canvas.drawRRect(handleRRect, Paint()..color = handleColor);

    final headHeight = h * 0.22;
    final headRect = Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.84, headHeight);
    final headRRect = RRect.fromRectAndRadius(
      headRect,
      Radius.circular(headHeight * 0.18),
    );
    canvas.drawRRect(headRRect, Paint()..color = headColor);

    final collarRect = Rect.fromLTWH(w * 0.20, h * 0.30, w * 0.40, h * 0.04);
    canvas.drawRect(
      collarRect,
      Paint()..color = headColor.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(covariant _HammerPainter old) =>
      old.headColor != headColor || old.handleColor != handleColor;
}
