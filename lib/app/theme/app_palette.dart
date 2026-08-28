part of 'app_colors.dart';

/// TIER 1 — primitives, lifted from the Figma foundation
/// (`JobDun-Screens` → Foundation, node 14:1962). Six ramps of eleven steps;
/// only the steps a theme actually consumes are declared here, plus two
/// hand-tuned customs that fill gaps the ramp skips.
///
/// Private to the `app_colors.dart` library: widgets must go through
/// [JColors]; nothing outside this library can reach `_Palette`.
///
/// **Light is the canonical theme.** Dark is not an inversion of it — each
/// token is picked independently from these ramps so both clear WCAG on their
/// own ground (see `test/colors_contrast_test.dart`).
class _Palette {
  _Palette._();

  // ── Neutral — pure achromatic grey, no hue bias at any step ───────────────
  // Replaced the blue-leaning slate ramp when the system went light-first.
  static const white = Color(0xFFFFFFFF); // light surface / card
  static const neutral50 = Color(0xFFF8F8F8); // light background / dark text1
  static const neutral100 = Color(0xFFF2F2F2); // light surfaceRaised
  static const neutral200 = Color(0xFFE4E4E4); // light border
  static const neutral300 = Color(0xFFC8C8C8); // dark text2
  static const neutral400 = Color(0xFFADADAD); // dark text3
  static const neutral500 = Color(0xFF919191); // dark borderStrong (4.25)
  static const neutral550 = Color(
    0xFF8C8C8C,
  ); // CUSTOM — light borderStrong. neutral500 is 2.97 on the light ground,
  // a hair under the 3:1 non-text floor, and neutral600 reads too heavy.
  static const neutral700 = Color(0xFF5E5E5E); // light text3
  static const neutral800 = Color(
    0xFF474747,
  ); // light text2 / dark raised + dark border
  static const neutral900 = Color(0xFF2F2F2F); // dark surface / card
  static const neutral950 = Color(0xFF181818); // dark background / onAction
  static const ink = Color(0xFF111118); // light text1 (Figma text/primary)

  // ── Brand — the ONE brand colour ──────────────────────────────────────────
  static const brand50 = Color(0xFFFFF6F2); // light actionBg
  static const brand200 = Color(0xFFFEDCCC); // dark actionTx
  static const brand500 = Color(0xFFFD7434); // dark actionInk (4.92 on surface)
  static const brand600 = Color(0xFFFC5101); // action (both)
  static const brand650 = Color(
    0xFFED4C01,
  ); // CUSTOM — pressed. ~6% darker at the same 19.1° hue; brand700 would drop
  // `onAction` to 3.61 and fail, so the ramp's own step can't be used here.
  static const brand700 = Color(0xFFCA4101); // light actionInk (4.92 on white)
  static const brand800 = Color(0xFF973101); // light actionTx
  static const brand950 = Color(0xFF321000); // dark actionBg

  // ── Success ───────────────────────────────────────────────────────────────
  static const success50 = Color(0xFFF3F9F5); // light verifiedBg
  static const success300 = Color(0xFFA2CFB3); // dark verifiedTx
  static const success500 = Color(0xFF459F66); // dark verified
  static const success600 = Color(0xFF178740); // light verified
  static const success800 = Color(0xFF0E5126); // light verifiedTx
  static const success950 = Color(0xFF051B0D); // dark verifiedBg

  // ── Danger ────────────────────────────────────────────────────────────────
  static const danger50 = Color(0xFFFEF3F3); // light urgentBg
  static const danger300 = Color(0xFFF7A1A1); // dark urgentTx
  static const danger500 = Color(0xFFEF4343); // dark urgent
  static const danger600 = Color(0xFFEB1414); // light urgent
  static const danger800 = Color(0xFF8D0C0C); // light urgentTx
  static const danger950 = Color(0xFF2F0404); // dark urgentBg

  // ── Info (status only) ────────────────────────────────────────────────────
  static const info50 = Color(0xFFF3F7FE); // light availableBg
  static const info300 = Color(0xFFA3C5FB); // dark availableTx
  static const info500 = Color(0xFF488BF6); // dark available
  static const info600 = Color(0xFF1A6EF4); // light available
  static const info800 = Color(0xFF104292); // light availableTx
  static const info950 = Color(0xFF051631); // dark availableBg

  // ── Warning (caution + rating star) ───────────────────────────────────────
  // Olive-gold rather than amber. On the dark ground warning600 manages only
  // 2.06 on surface, so dark steps up to warning400.
  static const warning50 = Color(0xFFF9F8F2); // light warningBg
  static const warning300 = Color(0xFFD2C799); // dark warningTx
  static const warning400 = Color(0xFFBBAA67); // dark warning + dark star
  static const warning600 = Color(0xFF8E7201); // light warning + light star
  static const warning800 = Color(0xFF554401); // light warningTx
  static const warning950 = Color(0xFF1C1700); // dark warningBg
}
