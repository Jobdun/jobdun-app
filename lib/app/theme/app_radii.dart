/// Radius scale — semantic names, not t-shirt sizes.
///
/// **MASTER §238 (anti-pattern):** "Soft/rounded border radius above 12 — keep
/// it sharp (4–8)" *in app chrome*. Everything from [badge] to [avatar] lives
/// in that 4–8 band on purpose. Do not add a `card2 = 16` or `dialog = 24` for
/// in-app surfaces without revisiting MASTER first.
///
/// The two `overlay*` tokens at the bottom are the documented exception: the
/// onboarding / marketing hero surfaces drawn on the Figma foundation
/// (`JobDun-Screens` → Onboard, node 17:5084) float cards *over a photograph*
/// rather than sitting in the app's flat chrome, and use 12–16 there. They are
/// scoped to that job — reach for [card] anywhere inside the app shell.
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

  /// 12dp — small chips floating **over a photo** (the onboarding hero's
  /// suburb pins). Onboarding/marketing surfaces only — see the class doc.
  static const overlayChip = 12.0;

  /// 16dp — cards floating **over a photo** and the onboarding role-picker
  /// sheet. Onboarding/marketing surfaces only — see the class doc.
  static const overlayCard = 16.0;
}
