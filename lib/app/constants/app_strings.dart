/// Centralised user-facing copy for Jobdun — the copy analogue of `AppIcons`
/// over Phosphor. Feature code references these constants instead of
/// hard-coding labels, so a wording change is a one-line data edit rather than
/// a hunt across screens (and the job-detail CTA can never drift from the
/// quote sheet's submit button).
///
/// **Naming rule — read before adding a constant.** Names describe the ACTION
/// they trigger or the STATE they describe, never the word currently shown.
/// The label "Quote this job" lives behind [respondToJob], not `quoteButton`,
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
  ///
  /// Sentence case since 2026-08-29: Job Details was rebuilt on the Figma
  /// Homepage section, which sets every button in sentence case. The mock only
  /// draws the builder-owned footer, but leaving the tradie CTA shouting on an
  /// otherwise sentence-case screen read as an oversight. Single call site.
  static const String respondToJob = 'Quote this job';

  /// Eyebrow above the quote sheet (`PageHeader`).
  static const String respondSheetTitle = 'SEND A QUOTE';

  /// Submit button inside the quote sheet.
  static const String respondSubmit = 'SEND QUOTE';

  /// Submit button while the quote is in flight.
  static const String respondSubmitting = 'SENDING…';

  /// Confirmed state once the tradie has quoted.
  static const String respondedState = 'QUOTE SENT';

  /// Inline action for a tradie to pull back a pending application.
  /// 2026-08-18 audit (#8): the handler withdraws the APPLICATION (the swipe
  /// action for the same callback says 'WITHDRAW'), so the label must not
  /// say "quote".
  static const String withdrawFromJob = 'Withdraw application';
}
