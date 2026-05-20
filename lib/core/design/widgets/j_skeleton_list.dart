import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../colors.dart';

/// Skeleton-shimmer wrapper for content-shaped loading states.
///
/// Drop in as a one-line replacement for the
/// `if (isLoading) const CircularProgressIndicator() else child` pattern on
/// list-of-cards / profile-block surfaces.
///
/// Use this when the loading layout matches the loaded layout (a list of
/// JobCards, a profile body of stat tiles + JCards). For overlay progress
/// (avatar upload spinner, recenter-map button) keep
/// [CircularProgressIndicator] — those are not content reveals.
///
/// Tokens.
/// - Base = `c.surface`, highlight = `c.surfaceRaised` — keeps the shimmer
///   inside the existing dark palette instead of the Skeletonizer default
///   greys.
/// - Pulse = 1200ms. The MASTER 150–200ms window is for *transition*
///   easing; shimmer cadence is a separate visual rhythm and the
///   industry-standard 1200ms feels right against the slate background.
class JSkeletonList extends StatelessWidget {
  const JSkeletonList({super.key, required this.enabled, required this.child});

  /// Toggle the shimmer mask. When `false`, [child] renders as-is — no
  /// reflow, no rebuild gap.
  final bool enabled;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Skeletonizer(
      enabled: enabled,
      effect: ShimmerEffect(
        baseColor: c.surface,
        highlightColor: c.surfaceRaised,
        duration: const Duration(milliseconds: 1200),
      ),
      child: child,
    );
  }
}
