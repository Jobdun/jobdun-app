/// Spacing scale — use with `flutter_screenutil`'s `.w` / `.h` extensions, never raw.
///
/// **MASTER §85-94.** Six tokens cover the entire app; if you need 12dp,
/// reach for `AppSpacing.md` (16dp) instead. The 4dp grid is non-negotiable.
///
/// Used via `Gap(AppSpacing.md.h)` or `EdgeInsets.all(AppSpacing.lg.w)`.
abstract final class AppSpacing {
  /// 4dp — icon-internal gaps, tight visual links.
  static const xs = 4.0;

  /// 8dp — inline spacing between related items.
  static const sm = 8.0;

  /// 16dp — standard padding inside cards, sections, list rows.
  static const md = 16.0;

  /// 24dp — section padding, screen horizontal margins.
  static const lg = 24.0;

  /// 32dp — large section gaps, hero-to-content spacing.
  static const xl = 32.0;

  /// 48dp — screen-level margins, top-of-page rhythm.
  static const xxl = 48.0;
}
