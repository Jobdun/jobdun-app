import 'package:flutter/widgets.dart';

/// Locked icon rendering config. Brand-level decisions (fill cross-fade
/// timing, curve) centralized so a single edit retunes the whole app's icon
/// language.
///
/// Tabler has no variable-weight axis like Material Symbols, so the
/// outline→filled transition is a cross-fade between two glyphs rather than
/// an axis tween. This file is intentionally minimal; Phase 2+ adds default
/// colour fallback / opacity rules here in one place.
class AppIconTheme {
  AppIconTheme._();

  /// Duration of the inactive→active glyph cross-fade.
  static const inactiveFillDuration = Duration(milliseconds: 150);

  /// Easing for the fill cross-fade. Matches MASTER motion (no bounce).
  static const fillCurve = Curves.easeOut;
}
