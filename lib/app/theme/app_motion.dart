import 'package:flutter/animation.dart';

/// Motion tokens — durations and curve for in-app transitions.
///
/// **MASTER §216:** "Transitions: 150–200ms ease. No longer." Anything past
/// 200ms reads as a SaaS loading state, not a tradie tool. There is
/// deliberately no `slow` token.
abstract final class AppMotion {
  /// 150ms — taps, micro-interactions, ripple-equivalent flashes.
  static const fast = Duration(milliseconds: 150);

  /// 200ms — page-level transitions, sheet enter/exit, snackbars.
  static const medium = Duration(milliseconds: 200);

  /// Default curve for both [fast] and [medium]. Maps to MASTER's "ease".
  static const standard = Curves.easeOutCubic;
}
