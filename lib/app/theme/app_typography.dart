import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Jobdun type scale — the **new** (2026-05-31) ~1.2 "minor third" ramp.
///
/// Body anchored at 16; distinct sizes 40 / 32 / 26 / 22 / 18 / 16 / 14 / 12 / 11
/// (the old 15/14/13 1-px cluster is gone). Line-heights are explicit on every
/// role; tracking is neutral on display/headings and positive only on small
/// caps/labels. See `design-system/jobdun/MASTER.md` → Typography.
///
/// **Fixed logical px — never `.sp` on `fontSize`.** `.sp` scales by screen width
/// and ignores the OS text-size setting; the scaler is clamped in
/// `MaterialApp.builder` instead.
///
/// Fonts still resolve through `google_fonts` (Oswald + Open Sans) so the scale
/// renders immediately. Bundling the static weights as assets (kill the runtime
/// fetch for offline worksites) is a separate tracked migration — when it lands,
/// swap the two helpers below to `TextStyle(fontFamily: …)` and nothing else
/// changes.
///
/// Proven on `/design-preview`; wired into the global theme after sign-off.
abstract final class AppTypography {
  /// Wordmark ONLY — the wide 3.0 tracking is brand, not part of the scale.
  /// Example: `Text('JOBDUN', style: AppTypography.brandDisplay(context.c.text1))`.
  static TextStyle brandDisplay(Color color) => GoogleFonts.oswald(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: 3.0,
    height: 1.0,
    color: color,
  );

  /// Tabular figures for money / counts / ratings so digits align and the line
  /// width doesn't jitter as values change. Wrap any numeric run:
  /// `Text(r'$85/hr', style: AppTypography.numeric(tt.titleLarge!))`.
  static TextStyle numeric(TextStyle base) =>
      base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Builds the Material 3 [TextTheme] from the three text-emphasis tokens.
  static TextTheme textTheme({
    required Color text1,
    required Color text2,
    required Color text3,
  }) {
    TextStyle os(double size, FontWeight w, double ls, double h, Color c) =>
        GoogleFonts.oswald(
          fontSize: size,
          fontWeight: w,
          letterSpacing: ls,
          height: h,
          color: c,
        );
    TextStyle sans(double size, FontWeight w, double ls, double h, Color c) =>
        GoogleFonts.openSans(
          fontSize: size,
          fontWeight: w,
          letterSpacing: ls,
          height: h,
          color: c,
        );

    return TextTheme(
      displayLarge: os(40, FontWeight.w700, 0, 1.10, text1),
      displayMedium: os(36, FontWeight.w700, 0, 1.10, text1), // rare
      displaySmall: os(32, FontWeight.w700, 0, 1.12, text1), // rare
      headlineLarge: os(32, FontWeight.w700, 0, 1.15, text1),
      headlineMedium: os(26, FontWeight.w600, 0.15, 1.20, text1),
      headlineSmall: os(22, FontWeight.w600, 0.15, 1.25, text1),
      titleLarge: os(18, FontWeight.w600, 0.15, 1.30, text1),
      titleMedium: sans(16, FontWeight.w600, 0, 1.50, text1),
      titleSmall: sans(14, FontWeight.w600, 0, 1.40, text1),
      bodyLarge: sans(16, FontWeight.w400, 0, 1.50, text1),
      bodyMedium: sans(14, FontWeight.w400, 0, 1.50, text2),
      bodySmall: sans(12, FontWeight.w500, 0.1, 1.40, text2),
      labelLarge: os(14, FontWeight.w700, 1.2, 1.10, text1), // CAPS via widget
      labelMedium: sans(12, FontWeight.w600, 0.4, 1.20, text2),
      labelSmall: sans(11, FontWeight.w600, 0.6, 1.20, text3),
    );
  }
}

/// Admin-console type scale. The admin web app (`lib/admin/**`) uses the same
/// Archivo + Inter pairing as the marketing website, but keeps its own
/// desktop-density sizes and tighter product-UI rhythm.
///
/// Centralising them here is not optional decoration: the repo-wide design lint
/// (`scripts/validate.sh`) forbids `GoogleFonts.*` anywhere under `lib/` except
/// `app_theme.dart` and this file. Every admin widget therefore styles text
/// through these roles instead of hand-rolling `GoogleFonts.oswald(...)` — one
/// source of type truth, and a green design check.
///
/// Each role takes its colour explicitly. Admin ships dark-only today, but call
/// sites still pass `context.c.*` tokens so the values lerp correctly if the
/// console ever follows the app's theme mode.
abstract final class AdminText {
  static TextStyle _arch(
    double size,
    FontWeight w,
    double ls,
    double h,
    Color c,
  ) => GoogleFonts.archivo(
    fontSize: size,
    fontWeight: w,
    letterSpacing: ls,
    height: h,
    color: c,
  );

  static TextStyle _inter(
    double size,
    FontWeight w,
    double ls,
    double h,
    Color c,
  ) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: w,
    letterSpacing: ls,
    height: h,
    color: c,
  );

  // ── Archivo — display / headings / high-intent labels ────────────────────
  /// Page hero (dashboard "WELCOME, ADMIN.").
  static TextStyle display(Color c) =>
      _arch(40, FontWeight.w800, -0.3, 1.05, c);

  /// Sidebar / login wordmark — wide brand tracking.
  static TextStyle wordmark(Color c) => _arch(22, FontWeight.w800, 0.8, 1.0, c);

  /// Big metric number on dashboard stat tiles.
  static TextStyle statValue(Color c) =>
      _arch(32, FontWeight.w800, -0.2, 1.0, c);

  /// Dialog / review-sheet title.
  static TextStyle dialogTitle(Color c) =>
      _arch(22, FontWeight.w800, 0, 1.12, c);

  /// Topbar title + login "RESTRICTED ACCESS".
  static TextStyle pageTitle(Color c) => _arch(20, FontWeight.w700, 0, 1.18, c);

  /// In-page section header (PENDING / REVIEWED, error-block titles).
  static TextStyle sectionTitle(Color c) =>
      _arch(18, FontWeight.w800, 0.6, 1.18, c);

  /// Detail-card header eyebrow (PROFILE / BUILDER / TRADE / VERIFICATIONS).
  static TextStyle cardLabel(Color c) =>
      _arch(13, FontWeight.w800, 1.0, 1.15, c);

  /// All-caps nav / chip / button label.
  static TextStyle label(Color c) => _arch(12, FontWeight.w800, 0.9, 1.15, c);

  // ── Inter — body / dense data / small labels ─────────────────────────────
  /// Intro / explanatory body copy.
  static TextStyle body(Color c) => _inter(14, FontWeight.w400, 0, 1.55, c);

  /// Emphasised inline value (names, primary cell text).
  static TextStyle bodyStrong(Color c) =>
      _inter(13, FontWeight.w600, 0, 1.45, c);

  /// Default value / card copy.
  static TextStyle value(Color c) => _inter(13, FontWeight.w400, 0, 1.55, c);

  /// Text inside ad-hoc input fields.
  static TextStyle input(Color c) => _inter(13, FontWeight.w500, 0, 1.35, c);

  /// Timestamps, hints, secondary metadata.
  static TextStyle meta(Color c) => _inter(12, FontWeight.w400, 0, 1.45, c);

  /// Sentence-case form / KV label.
  static TextStyle labelMd(Color c) => _inter(12, FontWeight.w600, 0.4, 1.2, c);

  /// Small caption.
  static TextStyle caption(Color c) => _inter(11, FontWeight.w600, 0, 1.35, c);

  /// Eyebrow / micro-label (stat labels, "SIGNED IN AS", badges).
  static TextStyle eyebrow(Color c) => _inter(10, FontWeight.w700, 1.2, 1.2, c);

  /// Monospace — raw regulator JSON payloads in the verification viewer.
  static TextStyle mono(Color c) =>
      GoogleFonts.robotoMono(fontSize: 11, height: 1.4, color: c);
}
