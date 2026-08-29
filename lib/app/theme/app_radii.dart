/// Radius scale — semantic names, not t-shirt sizes.
///
/// **2026-08-29 — the band widened.** MASTER's original "keep it sharp (4–8)"
/// was written when every surface shared one radius. The Figma foundation
/// splits it by role instead, and the tokens follow: containers stay sharp
/// (4–8), *controls* round (inputs 12, buttons pill). See MASTER → Radius.
///
/// The two `overlay*` tokens at the bottom are a further exception: the
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

  /// Fully rounded — primary CTA + secondary buttons. Figma draws these as
  /// `rounded-[48px]` on a 48dp-tall button, i.e. a pill. Kept as a large
  /// constant rather than height/2 so a button that grows (two-line label,
  /// larger text scale) stays a pill instead of turning into a stadium with
  /// square-ish ends.
  static const btn = 999.0;

  /// 8dp — cards, bottom sheets, dialog surfaces (MASTER §147).
  static const card = 8.0;

  /// 16dp — the softer card radius the Figma **Homepage** section draws
  /// (`JobDun-Screens` → Homepage, node 64:2088): the home stat row, map promo,
  /// quick-action pair, the profile-completion card, and the job-flow surfaces
  /// built from the same section.
  ///
  /// Deliberately a *second* card token rather than a bump to [card]. The
  /// rounder language is only signed off for the screens rebuilt on that
  /// section; widening [card] would restyle every other surface in the app in
  /// the same commit. Retire this and fold it into [card] once the rest of the
  /// screens are redrawn on the Figma foundation.
  static const cardLg = 16.0;

  /// 12dp — input fields. Figma `border-radius/md`; the auth screens
  /// (`JobDun-Screens` → Login, node 60:267) build every field on it, and it
  /// is the value the whole form vocabulary is drawn at.
  static const input = 12.0;

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
