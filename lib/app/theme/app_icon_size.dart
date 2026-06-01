/// Icon size scale — Material-aligned semantic steps. Use with
/// `flutter_screenutil`'s `.r`, e.g. `Icon(AppIcons.search, size: AppIconSize.md.r)`.
///
/// **Why this exists.** `AppIcons` centralises the icon *glyphs*, but icon
/// *sizes* were hand-picked per call site. This pins the scale the way
/// `AppSpacing`/`AppRadius` pin spacing and corners, so the use-case decides
/// the size, not the developer — and one edit here re-flows every call site.
///
/// **2026-06-01 — aligned to the Material standard.** Material's default UI /
/// list icon is **24dp**; buttons & chips use **18dp**; dense metadata sits at
/// **16dp**. The old 14/16/20 floor read small next to the new 16px type scale,
/// so the steps moved up: micro 14→16 · inline 16→18 · md 20→24. Nav / feature /
/// hero were already on the Material grid (24 / 32 / 40) and are unchanged.
abstract final class AppIconSize {
  /// 16dp — dense metadata micro-glyphs paired with caption text (a location
  /// pin beside a 12sp suburb, inline status dots). Material's smallest
  /// comfortably-legible step; reserved for text-adjacent micro-icons.
  static const micro = 16.0;

  /// 18dp — inline icons inside buttons, chips, and labels (Material's
  /// button/chip icon size).
  static const inline = 18.0;

  /// 24dp — the default UI icon: list-row leading glyphs, trailing chevrons,
  /// field affordances (eye toggle, prefix icons). Material's standard size.
  static const md = 24.0;

  /// 24dp — navigation: bottom nav items, app-bar actions. Same value as [md]
  /// (Material puts nav and list icons on the same 24dp step); kept as a
  /// distinct name so nav call-sites read intentionally.
  static const nav = 24.0;

  /// 32dp — feature / section icons and primary-action tiles.
  static const feature = 32.0;

  /// 40dp — empty-state and hero icons.
  static const hero = 40.0;
}
