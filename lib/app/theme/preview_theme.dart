import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_theme.dart';
import 'app_typography.dart';

/// PREVIEW-ONLY spacing scale — the proposed denser **4 / 8 / 12 / 16 / 24 / 32 / 48**
/// rhythm (MASTER 2026-05-31 decision). Exists so `/design-preview` can render the
/// new scale live **without** redefining the global [AppSpacing] (324 call sites) and
/// silently shifting the whole app. After sign-off, `AppSpacing` migrates to these
/// values in one mechanical pass and this class is deleted. Use with `.w`/`.h` like
/// `AppSpacing` — screenutil stays; only the numbers change.
abstract final class PreviewSpace {
  static const xs = 4.0; // icon-internal gaps
  static const sm = 8.0; // tight inline spacing
  static const md = 12.0; // compact padding (NEW — was absent)
  static const lg = 16.0; // standard padding / card inset (was 24)
  static const xl = 24.0; // section padding (was 32)
  static const xxl = 32.0; // large section gaps (was 48)
  static const xxxl = 48.0; // screen-level margins
}

/// PREVIEW-ONLY theme. Applies the accessibility fixes proposed in
/// `docs/DESIGN_SYSTEM_SUGGESTIONS.md` on top of the live themes **without
/// touching the global theme**, so the corrected tokens can be eyeballed on
/// the `/home-preview` A/B page (debug only).
///
/// Provides BOTH a fixed-dark and a fixed-light variant so the page can offer a
/// brightness toggle. Note the live app is dark-only and its light theme uses a
/// near-white background the design system bans — the light variant exists
/// purely so the corrected tokens can be inspected in both modes.
///
/// NOT wired into the app shell. The real fix would edit `app_colors.dart` and
/// add a dedicated `borderStrong` token rather than repurposing `border`.
///
/// Fixes applied (ratios verified in `docs/DESIGN_SYSTEM_TOKENS.md`):
///  - `onAction`  white (2.80:1) → #0F172A (6.37:1)            [S0-CTA]
///  - `text3`     → 5.0:1 (dark) / 4.76:1 (light)              [S1-TEXT3]
///  - `border`    → #708096 (3.63:1 dark / 4.03:1 light)       [S2-BORDER]
///  - `labelSmall` 10→11sp, `bodySmall` 11→12sp                [S5-TYPE-FLOOR]
///  - `bodyMedium` line-height → 1.45                          [S13-LEADING]
abstract final class PreviewTheme {
  static final JColors fixedColorsDark = JColors.dark.copyWith(
    onAction: const Color(0xFF0F172A), // dark text on orange — 6.37:1
    text3: const Color(0xFF8B98AB), // tertiary — 5.0:1 on surface
    border: const Color(0xFF708096), // interactive boundary — 3.63:1
  );

  static final JColors fixedColorsLight = JColors.light.copyWith(
    onAction: const Color(0xFF0F172A), // dark text on orange — 6.37:1
    text3: const Color(0xFF64748B), // tertiary — 4.76:1 on white
    border: const Color(0xFF708096), // interactive boundary — 4.03:1
  );

  static ThemeData fixedDark() => _apply(AppTheme.dark(), fixedColorsDark);
  static ThemeData fixedLight() => _apply(AppTheme.light(), fixedColorsLight);

  /// `fixedDark` PLUS the **new** [AppTypography] scale (40/32/26/22/18/16/14/12/11,
  /// explicit line-heights, ratified tracking). The full proposed setup, live, so the
  /// type ramp + denser spacing can be eyeballed before the global theme migration.
  static ThemeData designV2Dark() {
    final c = fixedColorsDark;
    return _apply(AppTheme.dark(), c).copyWith(
      textTheme: AppTypography.textTheme(
        text1: c.text1,
        text2: c.text2,
        text3: c.text3,
      ),
    );
  }

  static ThemeData _apply(ThemeData base, JColors c) {
    // Reuse the base styles (keeps the already-resolved Archivo/Inter
    // families) and only bump the failing sizes / line-heights.
    final textTheme = base.textTheme.copyWith(
      bodyMedium: base.textTheme.bodyMedium!.copyWith(height: 1.45),
      bodySmall: base.textTheme.bodySmall!.copyWith(fontSize: 12),
      labelSmall: base.textTheme.labelSmall!.copyWith(
        fontSize: 11,
        color: c.text3,
      ),
    );

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: BorderSide(color: color, width: width),
    );

    return base.copyWith(
      extensions: [c],
      textTheme: textTheme,
      // Best-practice icon defaults: 24dp on the 8pt grid (MASTER §210 nav
      // size) and the legible `text2` instead of the failing `text3` for icons
      // that don't set their own size/colour. The 48dp tap-target floor and
      // `MaterialTapTargetSize.padded` are inherited from the base theme
      // (app_theme.dart:176/188) — they already satisfy iOS 44pt / Android 48dp.
      iconTheme: base.iconTheme.copyWith(size: 24, color: c.text2),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        border: border(c.border, 1),
        enabledBorder: border(c.border, 1),
      ),
      cardTheme: base.cardTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.card)),
          side: BorderSide(color: c.border),
        ),
      ),
    );
  }
}
