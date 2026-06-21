import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Jobdun type scale — the **new** (2026-06-17) Archivo + Inter ramp.
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
/// Fonts still resolve through `google_fonts` (Archivo + Inter) so the scale
/// renders immediately. Bundling the static weights as assets (kill the runtime
/// fetch for offline worksites) is a separate tracked migration; when it lands,
/// swap the two helpers below to `TextStyle(fontFamily: ...)` and nothing else
/// changes.
///
/// Proven on `/design-preview`; wired into the global theme after sign-off.
abstract final class AppTypography {
  /// Wordmark ONLY — tuned to sit beside the hammer-J badge.
  /// Example: `Text('JOBDUN', style: AppTypography.brandDisplay(context.c.text1))`.
  static TextStyle brandDisplay(Color color) => GoogleFonts.archivo(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
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
    TextStyle arch(double size, FontWeight w, double ls, double h, Color c) =>
        GoogleFonts.archivo(
          fontSize: size,
          fontWeight: w,
          letterSpacing: ls,
          height: h,
          color: c,
        );
    TextStyle inter(double size, FontWeight w, double ls, double h, Color c) =>
        GoogleFonts.inter(
          fontSize: size,
          fontWeight: w,
          letterSpacing: ls,
          height: h,
          color: c,
        );

    return TextTheme(
      displayLarge: arch(40, FontWeight.w800, 0, 1.06, text1),
      displayMedium: arch(36, FontWeight.w800, 0, 1.08, text1), // rare
      displaySmall: arch(32, FontWeight.w800, 0, 1.10, text1), // rare
      headlineLarge: arch(32, FontWeight.w800, 0, 1.12, text1),
      headlineMedium: arch(26, FontWeight.w700, 0, 1.18, text1),
      headlineSmall: arch(22, FontWeight.w700, 0, 1.22, text1),
      titleLarge: arch(18, FontWeight.w700, 0, 1.25, text1),
      titleMedium: inter(16, FontWeight.w600, 0, 1.50, text1),
      titleSmall: inter(14, FontWeight.w600, 0, 1.40, text1),
      bodyLarge: inter(16, FontWeight.w400, 0, 1.55, text1),
      bodyMedium: inter(14, FontWeight.w400, 0, 1.55, text2),
      bodySmall: inter(12, FontWeight.w500, 0.1, 1.45, text2),
      labelLarge: arch(
        14,
        FontWeight.w800,
        0.8,
        1.10,
        text1,
      ), // CAPS via widget
      labelMedium: inter(12, FontWeight.w600, 0.35, 1.20, text2),
      labelSmall: inter(11, FontWeight.w700, 0.5, 1.20, text3),
    );
  }
}

/// Admin-console type scale. The admin web app (`lib/admin/**`) keeps its own
/// desktop-density Oswald + Open Sans roles until the admin console typography
/// branch lands.
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
  static TextStyle _os(
    double size,
    FontWeight w,
    double ls,
    double h,
    Color c,
  ) => GoogleFonts.oswald(
    fontSize: size,
    fontWeight: w,
    letterSpacing: ls,
    height: h,
    color: c,
  );

  static TextStyle _sans(
    double size,
    FontWeight w,
    double ls,
    double h,
    Color c,
  ) => GoogleFonts.openSans(
    fontSize: size,
    fontWeight: w,
    letterSpacing: ls,
    height: h,
    color: c,
  );

  // ── Oswald — display / headings ──────────────────────────────────────────
  /// Page hero (dashboard "WELCOME, ADMIN.").
  static TextStyle display(Color c) => _os(40, FontWeight.w700, 1.0, 1.1, c);

  /// Sidebar / login wordmark — wide brand tracking.
  static TextStyle wordmark(Color c) => _os(22, FontWeight.w700, 3.0, 1.0, c);

  /// Big metric number on dashboard stat tiles.
  static TextStyle statValue(Color c) => _os(32, FontWeight.w700, 0.5, 1.0, c);

  /// Dialog / review-sheet title.
  static TextStyle dialogTitle(Color c) => _os(22, FontWeight.w700, 0, 1.15, c);

  /// Topbar title + login "RESTRICTED ACCESS".
  static TextStyle pageTitle(Color c) => _os(20, FontWeight.w600, 0.5, 1.2, c);

  /// In-page section header (PENDING / REVIEWED, error-block titles).
  static TextStyle sectionTitle(Color c) =>
      _os(18, FontWeight.w700, 1.5, 1.2, c);

  /// Detail-card header eyebrow (PROFILE / BUILDER / TRADE / VERIFICATIONS).
  static TextStyle cardLabel(Color c) => _os(13, FontWeight.w700, 1.4, 1.2, c);

  // ── Open Sans — body / labels ────────────────────────────────────────────
  /// Intro / explanatory body copy.
  static TextStyle body(Color c) => _sans(14, FontWeight.w400, 0, 1.5, c);

  /// Emphasised inline value (names, primary cell text).
  static TextStyle bodyStrong(Color c) => _sans(13, FontWeight.w600, 0, 1.4, c);

  /// Default value / card copy.
  static TextStyle value(Color c) => _sans(13, FontWeight.w400, 0, 1.5, c);

  /// Text inside ad-hoc input fields.
  static TextStyle input(Color c) => _sans(13, FontWeight.w500, 0, 1.3, c);

  /// Timestamps, hints, secondary metadata.
  static TextStyle meta(Color c) => _sans(12, FontWeight.w400, 0, 1.4, c);

  /// All-caps nav / chip / button label.
  static TextStyle label(Color c) => _sans(12, FontWeight.w700, 1.2, 1.2, c);

  /// Sentence-case form / KV label.
  static TextStyle labelMd(Color c) => _sans(12, FontWeight.w600, 0.5, 1.2, c);

  /// Small caption.
  static TextStyle caption(Color c) => _sans(11, FontWeight.w600, 0, 1.3, c);

  /// Eyebrow / micro-label (stat labels, "SIGNED IN AS", badges).
  static TextStyle eyebrow(Color c) => _sans(10, FontWeight.w700, 1.4, 1.2, c);

  /// Monospace — raw regulator JSON payloads in the verification viewer.
  static TextStyle mono(Color c) =>
      GoogleFonts.robotoMono(fontSize: 11, height: 1.4, color: c);
}

/// Marketing-site type scale — **Archivo + Inter** (Option A, the recommended
/// pairing). Archivo is the industrial grotesque that matches the logo wordmark
/// and carries heavy display weights; Inter is the modern UI body face. It
/// lives here, beside [AppTypography] and [AdminText], because the design lint
/// only allows `GoogleFonts.*` in this file and `app_theme.dart`.
///
/// The website theme (`WebsiteTheme`) consumes this scale. Sizes / line-heights
/// mirror the app ramp so layout rhythm is unchanged across mobile and web.
abstract final class WebsiteText {
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

  /// Wordmark ONLY — Archivo heavy, tuned to sit beside the hammer-J badge.
  static TextStyle brandDisplay(Color color) => GoogleFonts.archivo(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
    height: 1.0,
    color: color,
  );

  /// Archivo (display/headings) + Inter (titles < 18 / body / small labels).
  static TextTheme textTheme({
    required Color text1,
    required Color text2,
    required Color text3,
  }) {
    return TextTheme(
      displayLarge: _arch(40, FontWeight.w800, -0.5, 1.05, text1),
      displayMedium: _arch(36, FontWeight.w800, -0.5, 1.08, text1),
      displaySmall: _arch(32, FontWeight.w700, -0.25, 1.10, text1),
      headlineLarge: _arch(32, FontWeight.w800, -0.25, 1.12, text1),
      headlineMedium: _arch(26, FontWeight.w700, 0, 1.20, text1),
      headlineSmall: _arch(22, FontWeight.w700, 0, 1.25, text1),
      titleLarge: _arch(18, FontWeight.w700, 0, 1.30, text1),
      titleMedium: _inter(16, FontWeight.w600, 0, 1.50, text1),
      titleSmall: _inter(14, FontWeight.w600, 0, 1.40, text1),
      bodyLarge: _inter(16, FontWeight.w400, 0, 1.55, text1),
      bodyMedium: _inter(14, FontWeight.w400, 0, 1.55, text2),
      bodySmall: _inter(12, FontWeight.w500, 0.1, 1.45, text2),
      labelLarge: _arch(
        14,
        FontWeight.w700,
        1.0,
        1.10,
        text1,
      ), // CAPS via widget
      labelMedium: _inter(12, FontWeight.w600, 0.4, 1.20, text2),
      labelSmall: _inter(11, FontWeight.w600, 0.6, 1.20, text3),
    );
  }

  /// Input label / hint / error styles (Inter) for the website input theme.
  static TextStyle inputLabel(Color c) =>
      _inter(11, FontWeight.w700, 0.8, 1.2, c);
  static TextStyle inputHint(Color c) => _inter(13, FontWeight.w400, 0, 1.3, c);
  static TextStyle inputError(Color c) =>
      _inter(11, FontWeight.w500, 0, 1.3, c);
}
