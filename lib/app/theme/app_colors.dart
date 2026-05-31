import 'package:flutter/material.dart';

// AppSpacing, AppRadius, and AppMotion live in their own files so the
// design-system lint can target token files independently of the colour
// extension. Re-exported here so files that imported app_colors.dart for
// the legacy combined surface continue to compile transparently.
//
// New code should import via `core/design/colors.dart` (the barrel).
export 'app_spacing.dart';
export 'app_radii.dart';
export 'app_motion.dart';
export 'app_icon_size.dart';

part 'app_palette.dart';

// ─── Colour system ─────────────────────────────────────────────────────────────
// Two tiers:
//   Tier 1 — `_Palette` (private): the raw Tailwind v3 ramps plus 4 hand-tuned
//            custom steps that fill gaps the ramp skips. Declared ONCE; widgets
//            never touch these.
//   Tier 2 — `JColors` (ThemeExtension): the semantic tokens widgets reference
//            via `context.c.xxx`. Theming + the WCAG contrast guard
//            (test/colors_contrast_test.dart) both live at this layer.
//
// Every fg/bg pair in the dark theme is verified ≥ its WCAG 2.2 bar by that
// test (normal text 4.5:1 · large text / UI components 3:1). Change a hex here
// and the guard re-checks it.

// Tier 1 primitives (`_Palette`) live in `app_palette.dart` (a `part` of this
// library) — kept private there so widgets can only reach colour through JColors.

// ─── Theme Extension ──────────────────────────────────────────────────────────
// Use `context.c.xxx` in all widgets. ThemeExtension lerps smoothly on
// animated theme switches.

class JColors extends ThemeExtension<JColors> {
  const JColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.action,
    required this.actionPressed,
    required this.actionBg,
    required this.actionTx,
    required this.actionInk,
    required this.onAction,
    required this.verified,
    required this.verifiedBg,
    required this.verifiedTx,
    required this.urgent,
    required this.urgentBg,
    required this.urgentTx,
    required this.available,
    required this.availableBg,
    required this.availableTx,
    required this.warning,
    required this.warningBg,
    required this.warningTx,
    required this.star,
  });

  /// App background — dark slate (#0F172A). MASTER §38.
  /// MUST be used as the Scaffold background on every screen.
  /// MUST NOT be replaced by white or light gray (#F8FAFC) anywhere.
  final Color background;

  /// Standard surface — cards, bottom sheets, input fills. MASTER §39.
  /// MUST be used as the default elevated chrome on top of c.background.
  /// MUST NOT be used as a screen background — that's c.background.
  final Color surface;

  /// Alias of c.surface for CardTheme wiring. Same value, different role.
  final Color card;

  /// Raised surface — selected states, elevated cards, secondary buttons. MASTER §40.
  /// MUST be used when a surface needs to read as "above" c.surface.
  /// Carries c.text1 ONLY — c.text2/c.text3 fall below 4.5:1 on raised (MASTER a11y rule).
  final Color surfaceRaised;

  /// Input borders, dividers, hairlines. Same value as surfaceRaised by design. MASTER §45.
  /// MUST be used at 1.0 width for DECORATIVE borders and dividers (cards,
  /// list separators) where the surface fill already identifies the element.
  final Color border;

  /// Stronger boundary for INTERACTIVE controls (input fields, focusable
  /// surfaces) whose resting edge must clear the WCAG 1.4.11 3:1 non-text floor.
  /// `border` (#334155) is only ~1.4:1 — too faint for a control boundary — so
  /// inputs use this (#708096, 3.63:1 on surface) while cards keep `border`.
  final Color borderStrong;

  /// Primary text on dark backgrounds. MASTER §43.
  /// MUST be used for headlines, body copy, primary labels.
  final Color text1;

  /// Secondary text — labels, hints, metadata. MASTER §44.
  /// MUST be used for non-primary content (timestamps, helper text, decorative initials).
  /// MUST sit on c.background or c.surface only — never c.surfaceRaised (4.04:1).
  final Color text2;

  /// Tertiary text — eyebrow labels, muted captions, placeholders, "tappable-but-not-primary" inline links (underlined).
  /// MUST be used for FieldLabel content and the muted-link pattern (see login_page.dart Forgot? link).
  /// MUST sit on c.background or c.surface only — never c.surfaceRaised (3.54:1).
  final Color text3;

  /// Safety orange CTA accent. MASTER §51 reserved color.
  /// MUST be used for primary actions, loading indicators, URGENT badges, role chips.
  /// MUST NOT be used decoratively (avatar initials, location pins, timestamps) — use c.text2/c.text3 instead.
  final Color action;

  /// Pressed-state orange for c.action surfaces. ~12% darker than c.action.
  /// MUST be used only for pressed/highlight overlays on c.action elements.
  final Color actionPressed;

  /// Tinted orange background for orange-on-orange compositions (toast banners, pending badges).
  /// MUST be paired with c.actionTx text.
  /// MUST NOT be used as a standalone fill on top of c.background.
  final Color actionBg;

  /// Tinted orange text for c.actionBg backgrounds. Internal pair helper.
  final Color actionTx;

  /// Orange **ink** — orange used as TEXT or an ICON directly on the page
  /// (`background`/`surface`): inline links ("Create account"), legal links,
  /// eyebrow glyphs. Splits the brand orange's two jobs: `action` stays the
  /// FILL (button/CTA backgrounds, carried by `onAction`), while `actionInk`
  /// is the readable foreground. On dark it's the bright orange (6.37:1 on
  /// slate); on light it darkens to orange-700 (~4.95:1 on white) so it clears
  /// WCAG text — the bright orange is only 2.80:1 on white. NEVER use `action`
  /// for bare orange text/icons on a light surface; use this.
  final Color actionInk;

  /// Foreground when bg is c.action. Dark slate (#0F172A) — white on the
  /// safety-orange is only 2.80:1 and fails WCAG; dark-on-orange is 6.37:1.
  /// MUST be used as the text/icon color on primary CTAs and orange tiles.
  /// MUST NOT be used as a standalone text color elsewhere — use c.text1 instead.
  final Color onAction;

  /// Verified/success green. MASTER §47.
  /// MUST be used only for confirmations and verification checkmarks.
  /// MUST NOT be used decoratively.
  final Color verified;

  /// Tinted green background for verified-status pairs. Internal pair helper.
  final Color verifiedBg;

  /// Tinted green text for c.verifiedBg backgrounds. Internal pair helper.
  final Color verifiedTx;

  /// Error/destructive red. MASTER §46.
  /// MUST be used only for errors and destructive confirmations.
  /// MUST NOT be used decoratively, and MUST NOT stand in for caution — use c.warning.
  final Color urgent;

  /// Tinted red background for error/urgent pairs. Internal pair helper.
  final Color urgentBg;

  /// Tinted red text for c.urgentBg backgrounds. Internal pair helper.
  final Color urgentTx;

  /// Availability blue — informational/status only. NEVER a tappable action color.
  /// MUST be used for "Available now" status indicators.
  /// MUST NOT be used as a link/CTA color — use c.action for CTAs, or the muted-link pattern (underlined c.text3) for inline links.
  final Color available;

  /// Tinted blue background for availability pairs. Internal pair helper.
  final Color availableBg;

  /// Tinted blue text for c.availableBg backgrounds. Internal pair helper.
  final Color availableTx;

  /// Caution amber — non-destructive "needs attention" states a marketplace
  /// actually has: pending approval, verification-in-progress, listing expiring.
  /// MUST NOT reuse c.urgent (red) for these — red is reserved for errors/destruction.
  final Color warning;

  /// Tinted amber background for warning pairs. Internal pair helper.
  final Color warningBg;

  /// Tinted amber text for c.warningBg backgrounds. Internal pair helper.
  final Color warningTx;

  /// Star/rating amber. Decorative within rating widgets only.
  final Color star;

  static JColors of(BuildContext context) =>
      Theme.of(context).extension<JColors>()!;

  // ── Dark (the shipping theme — every pair verified by colors_contrast_test) ──
  static const dark = JColors(
    background: _Palette.slate900,
    surface: _Palette.slate800,
    card: _Palette.slate800,
    surfaceRaised: _Palette.slate700,
    border: _Palette.slate700,
    borderStrong: _Palette.slate550,
    text1: _Palette.slate100,
    text2: _Palette.slate400,
    text3: _Palette.slate450,
    action: _Palette.orange500,
    actionPressed: _Palette.orange550,
    actionBg: _Palette.orange950,
    actionTx: _Palette.orange200,
    actionInk: _Palette.orange500,
    onAction: _Palette.slate900,
    verified: _Palette.green500,
    verifiedBg: _Palette.green950,
    verifiedTx: _Palette.green300,
    urgent: _Palette.red500,
    urgentBg: _Palette.red950,
    urgentTx: _Palette.red300,
    available: _Palette.blue500,
    availableBg: _Palette.navy900,
    availableTx: _Palette.blue300,
    warning: _Palette.amber500,
    warningBg: _Palette.amber950,
    warningTx: _Palette.amber300,
    star: _Palette.amber500,
  );

  // ── Light (gated — app is dark-only; access via AppTheme._light() only) ───
  static const light = JColors(
    background: _Palette.slate50,
    surface: _Palette.white,
    card: _Palette.white,
    surfaceRaised: _Palette.slate100,
    border: _Palette.slate300,
    borderStrong: _Palette.slate550,
    text1: _Palette.slate900,
    text2: _Palette.slate600,
    text3: _Palette.slate500,
    action: _Palette.orange500,
    actionPressed: _Palette.orange550,
    actionBg: _Palette.orange100,
    actionTx: _Palette.orange800,
    actionInk: _Palette.orange700,
    onAction: _Palette.slate900,
    verified: _Palette.green600,
    verifiedBg: _Palette.green100,
    verifiedTx: _Palette.green800,
    urgent: _Palette.red600,
    urgentBg: _Palette.red100,
    urgentTx: _Palette.red800,
    available: _Palette.blue600,
    availableBg: _Palette.blue100,
    availableTx: _Palette.blue700,
    warning: _Palette.amber600,
    warningBg: _Palette.amber100,
    warningTx: _Palette.amber800,
    star: _Palette.amber600,
  );

  @override
  JColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? surfaceRaised,
    Color? border,
    Color? borderStrong,
    Color? text1,
    Color? text2,
    Color? text3,
    Color? action,
    Color? actionPressed,
    Color? actionBg,
    Color? actionTx,
    Color? actionInk,
    Color? onAction,
    Color? verified,
    Color? verifiedBg,
    Color? verifiedTx,
    Color? urgent,
    Color? urgentBg,
    Color? urgentTx,
    Color? available,
    Color? availableBg,
    Color? availableTx,
    Color? warning,
    Color? warningBg,
    Color? warningTx,
    Color? star,
  }) => JColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    card: card ?? this.card,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    border: border ?? this.border,
    borderStrong: borderStrong ?? this.borderStrong,
    text1: text1 ?? this.text1,
    text2: text2 ?? this.text2,
    text3: text3 ?? this.text3,
    action: action ?? this.action,
    actionPressed: actionPressed ?? this.actionPressed,
    actionBg: actionBg ?? this.actionBg,
    actionTx: actionTx ?? this.actionTx,
    actionInk: actionInk ?? this.actionInk,
    onAction: onAction ?? this.onAction,
    verified: verified ?? this.verified,
    verifiedBg: verifiedBg ?? this.verifiedBg,
    verifiedTx: verifiedTx ?? this.verifiedTx,
    urgent: urgent ?? this.urgent,
    urgentBg: urgentBg ?? this.urgentBg,
    urgentTx: urgentTx ?? this.urgentTx,
    available: available ?? this.available,
    availableBg: availableBg ?? this.availableBg,
    availableTx: availableTx ?? this.availableTx,
    warning: warning ?? this.warning,
    warningBg: warningBg ?? this.warningBg,
    warningTx: warningTx ?? this.warningTx,
    star: star ?? this.star,
  );

  @override
  JColors lerp(JColors? other, double t) {
    if (other == null) return this;
    return JColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      text1: Color.lerp(text1, other.text1, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      action: Color.lerp(action, other.action, t)!,
      actionPressed: Color.lerp(actionPressed, other.actionPressed, t)!,
      actionBg: Color.lerp(actionBg, other.actionBg, t)!,
      actionTx: Color.lerp(actionTx, other.actionTx, t)!,
      actionInk: Color.lerp(actionInk, other.actionInk, t)!,
      onAction: Color.lerp(onAction, other.onAction, t)!,
      verified: Color.lerp(verified, other.verified, t)!,
      verifiedBg: Color.lerp(verifiedBg, other.verifiedBg, t)!,
      verifiedTx: Color.lerp(verifiedTx, other.verifiedTx, t)!,
      urgent: Color.lerp(urgent, other.urgent, t)!,
      urgentBg: Color.lerp(urgentBg, other.urgentBg, t)!,
      urgentTx: Color.lerp(urgentTx, other.urgentTx, t)!,
      available: Color.lerp(available, other.available, t)!,
      availableBg: Color.lerp(availableBg, other.availableBg, t)!,
      availableTx: Color.lerp(availableTx, other.availableTx, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      warningTx: Color.lerp(warningTx, other.warningTx, t)!,
      star: Color.lerp(star, other.star, t)!,
    );
  }

  /// Every semantic token keyed by name. The single enumeration the contrast
  /// guard (test/colors_contrast_test.dart) drives token-coverage off, so a new
  /// token can't ship unguarded. MUST list every field declared above.
  Map<String, Color> toMap() => {
    'background': background,
    'surface': surface,
    'card': card,
    'surfaceRaised': surfaceRaised,
    'border': border,
    'borderStrong': borderStrong,
    'text1': text1,
    'text2': text2,
    'text3': text3,
    'action': action,
    'actionPressed': actionPressed,
    'actionBg': actionBg,
    'actionTx': actionTx,
    'actionInk': actionInk,
    'onAction': onAction,
    'verified': verified,
    'verifiedBg': verifiedBg,
    'verifiedTx': verifiedTx,
    'urgent': urgent,
    'urgentBg': urgentBg,
    'urgentTx': urgentTx,
    'available': available,
    'availableBg': availableBg,
    'availableTx': availableTx,
    'warning': warning,
    'warningBg': warningBg,
    'warningTx': warningTx,
    'star': star,
  };
}

/// Shorthand: `context.c.background`, `context.c.action`, etc.
extension JColorsX on BuildContext {
  JColors get c => JColors.of(this);
}
