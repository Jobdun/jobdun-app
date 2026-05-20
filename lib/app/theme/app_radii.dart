/// Radius scale — semantic names, not t-shirt sizes.
///
/// **MASTER §238 (anti-pattern):** "Soft/rounded border radius above 12 — keep
/// it sharp (4–8)." All values here live in the 4–8 band on purpose. Do not
/// add a `card2 = 16` or `dialog = 24` without revisiting MASTER first.
///
/// Used via `BorderRadius.circular(AppRadius.btn.r)` or `.input.r` etc.
abstract final class AppRadius {
  /// 4dp — small status chips, badges, dots.
  static const badge = 4.0;

  /// 6dp — filter pills, identity chips, button radius.
  static const chip = 6.0;

  /// 6dp — primary CTA + secondary buttons (MASTER §111).
  static const btn = 6.0;

  /// 8dp — cards, bottom sheets, dialog surfaces (MASTER §147).
  static const card = 8.0;

  /// 6dp — input fields (MASTER §165), matches `btn` so adjacent CTAs and
  /// inputs share a corner radius.
  static const input = 6.0;

  /// 8dp — avatar circle clipping (square avatars use this; round avatars use
  /// `BorderRadius.circular(...)` directly).
  static const avatar = 8.0;
}
