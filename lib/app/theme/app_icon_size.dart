/// Icon size scale — semantic names tied to MASTER §210's use-cases. Use with
/// `flutter_screenutil`'s `.r`, e.g. `Icon(AppIcons.search, size: AppIconSize.md.r)`.
///
/// **Why this exists.** `AppIcons` centralises the icon *glyphs*, but icon
/// *sizes* were hand-picked per call site — an audit found ~12 distinct values
/// (11–40) with ~21 uses below the 16dp inline floor and off-scale steps
/// (13/15/18/22/36). This pins the scale the way `AppSpacing`/`AppRadius` pin
/// spacing and corners, so the use-case decides the size, not the developer.
///
/// MASTER §210 mapping: inline 16–20 · nav 20–24 · feature 32–40.
abstract final class AppIconSize {
  /// 14dp — dense metadata micro-glyphs paired with caption text (a location
  /// pin beside a 12sp suburb, inline status dots). The only step below the
  /// inline floor, reserved for text-adjacent micro-icons.
  static const micro = 14.0;

  /// 16dp — inline icons inside buttons, chips, and labels (MASTER §210 inline).
  static const inline = 16.0;

  /// 20dp — default UI icons: list-row leading glyphs, trailing chevrons,
  /// field affordances (eye toggle, prefix icons).
  static const md = 20.0;

  /// 24dp — navigation: bottom nav items, app-bar actions (MASTER §210 nav).
  static const nav = 24.0;

  /// 32dp — feature / section icons and primary-action tiles (MASTER §210 feature).
  static const feature = 32.0;

  /// 40dp — empty-state and hero icons (MASTER §210 feature ceiling).
  static const hero = 40.0;
}
