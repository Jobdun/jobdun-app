import 'package:flutter/widgets.dart';

import '../../app/theme/app_motion.dart';

/// Locked icon rendering config — brand-level decisions about icon
/// size and active/inactive transition timing.
///
/// **One file retunes the entire icon language.** Sizes live here, not at
/// usage sites. Durations come from `AppMotion` so motion + icon tokens
/// stay in lock-step.
///
/// Phosphor weights are separate font files — there is no variable fill
/// axis. Active/inactive transitions are handled by cross-fading the
/// Bold (outline) and Fill (filled) variants, not by animating a single
/// icon's `fill` parameter.
abstract final class AppIconTheme {
  /// Default icon size when nothing else is specified.
  static const double defaultSize = 24.0;

  /// Bottom-nav icon size. Matches [defaultSize] today — kept separate so
  /// the nav can retune without affecting other surfaces.
  static const double navSize = 24.0;

  /// Cross-fade duration between outline and filled variants on
  /// selected-state changes. Pinned to `AppMotion.fast` so a single
  /// motion-token edit affects icons, snackbars, and ripples coherently.
  static const Duration fillDuration = AppMotion.fast;

  /// Curve used by the cross-fade.
  static const Curve fillCurve = AppMotion.standard;
}
