/// Centralised user-facing copy for Jobdun — the copy analogue of `AppIcons`
/// over Phosphor. Feature code references these constants instead of
/// hard-coding labels, so a wording change is a one-line data edit rather than
/// a hunt across screens (and the job-detail CTA can never drift from the
/// quote sheet's submit button).
///
/// **Naming rule — read before adding a constant.** Names describe the ACTION
/// they trigger or the STATE they describe, never the word currently shown.
/// The label "QUOTE THIS JOB" lives behind [respondToJob], not `quoteButton`,
/// so the name stays true if the copy changes again (quote → bid → interest).
///
/// **Casing.** Values are stored already-cased for their slot: ALL-CAPS for
/// [JButton] / `PageHeader` eyebrow labels (the app's button convention —
/// [JButton] does not upper-case), sentence case for inline links and body.
///
/// **Scope.** Intentionally just the trade-side respond/quote cluster for now,
/// not a full string sweep, and deliberately not ARB/l10n — overbuild for an
/// AU-only app. New user-facing copy should land here as the convention grows.
class AppStrings {
  AppStrings._();

  // ── Trade-side job actions ──────────────────────────────────────────────
  // The flow is a funnel, not a claim: a builder posts, several trades quote,
  // the builder picks one. The apply sheet collects a rate + note — that's a
  // quote — so the copy says "quote", never "accept" (which would falsely
  // promise the job before the builder has chosen).

  /// Primary CTA on the job-detail screen — opens the quote sheet.
  static const String respondToJob = 'QUOTE THIS JOB';

  /// Eyebrow above the quote sheet (`PageHeader`).
  static const String respondSheetTitle = 'SEND A QUOTE';

  /// Submit button inside the quote sheet.
  static const String respondSubmit = 'SEND QUOTE';

  /// Submit button while the quote is in flight.
  static const String respondSubmitting = 'SENDING…';

  /// Confirmed state once the tradie has quoted.
  static const String respondedState = 'QUOTE SENT';

  /// Inline action for a tradie to pull back a pending quote.
  static const String withdrawFromJob = 'Withdraw quote';
}
