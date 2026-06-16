import 'package:flutter/material.dart';

/// A 2-pixel solid bar (horizontal or vertical) with rounded ends.
/// Used as the "drawn" portion of the roadmap connector.
class RoadmapBar extends StatelessWidget {
  const RoadmapBar({super.key, required this.color, this.thickness = 2});
  final Color color;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: thickness,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(thickness / 2),
      ),
    );
  }
}

/// Custom clipper for the roadmap connector — reveals the drawn
/// portion of a horizontal or vertical bar as `progress` goes
/// 0 → 1. Used by the connector to "draw" the line on enter.
class RoadmapProgressClipper extends CustomClipper<Rect> {
  const RoadmapProgressClipper({
    required this.progress,
    required this.vertical,
  });
  final double progress;
  final bool vertical;
  @override
  Rect getClip(Size size) => vertical
      ? Rect.fromLTWH(0, 0, size.width, size.height * progress)
      : Rect.fromLTWH(0, 0, size.width * progress, size.height);
  @override
  bool shouldReclip(RoadmapProgressClipper old) =>
      old.progress != progress || old.vertical != vertical;
}
