import 'package:flutter/material.dart';

import '../../colors.dart';

/// Count bubble for a clustered group of map pins (map verdict #2) — dense
/// suburbs collapse to "7" instead of pin soup. Tapping zooms the map in
/// (the caller owns the camera).
class JMapClusterBubble extends StatelessWidget {
  const JMapClusterBubble({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      label: '$count jobs here. Zooms in.',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.action,
            shape: BoxShape.circle,
            border: Border.all(color: c.background, width: 2),
          ),
          child: Text(
            '$count',
            style: tt.titleSmall!.copyWith(
              fontWeight: FontWeight.w700,
              color: c.onAction,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
