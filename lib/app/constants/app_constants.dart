import 'dart:io';

class AppConstants {
  const AppConstants._();

  static const appName = 'Jobdun';
  static const appTagline = 'Construction workforce platform';
  static const appDescription =
      'Connect builders and trades in one mobile-first workflow.';
}

/// Icon glyph sizes (the drawn icon, not the tap area). Collapses the former
/// ad-hoc 12..48 spread into one scale. Apply `.r` at the call site as usual.
abstract final class AppIconSize {
  static const xs = 14.0; // dense metadata (was 12/13)
  static const sm = 16.0; // inline secondary
  static const md = 20.0; // default inline / nav inactive
  static const lg = 24.0; // nav active / prominent action
  static const xl = 32.0; // hero / section feature
  static const feature = 40.0; // large feature icon
  static const xxl = 48.0; // empty-state illustration
}

/// Platform-adaptive minimum interactive HIT AREA (not the glyph).
/// iOS HIG = 44pt, Material = 48dp. Use WITHOUT `.r`: an accessibility floor
/// must not shrink on small phones, and Flutter logical px are already
/// density-independent.
abstract final class AppTouchTarget {
  static const ios = 44.0;
  static const android = 48.0;
  static double get min => Platform.isIOS ? ios : android;
  static const gap = 8.0; // min spacing between adjacent targets
}

abstract final class AppElevation {
  static const none = 0.0;
}
