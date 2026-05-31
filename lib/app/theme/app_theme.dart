import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(JColors.light, Brightness.light);
  static ThemeData dark() => _build(JColors.dark, Brightness.dark);

  /// The Material 3 ColorScheme pinned to Jobdun tokens. Pure (no fonts) so the
  /// contrast guard can verify the on-pairs that drive stock Material widgets.
  /// `_build` consumes this too — single source for the scheme.
  static ColorScheme colorScheme(Brightness brightness) => _scheme(
    brightness == Brightness.dark ? JColors.dark : JColors.light,
    brightness,
  );

  static ColorScheme _scheme(JColors c, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    // fromSeed fills every M3 role (surface ramp, *Fixed, scrim, shadow);
    // copyWith pins the brand-critical ones to exact, contrast-verified hex.
    // Single-accent: secondary/tertiary reuse the orange — no green-as-tertiary
    // (that was white-on-green 2.28:1). Stock Material widgets theme from this.
    return ColorScheme.fromSeed(
      seedColor: c.action,
      brightness: brightness,
    ).copyWith(
      primary: c.action,
      onPrimary: c.onAction, // 6.37:1
      primaryContainer: c.actionBg,
      onPrimaryContainer: c.actionTx, // dark 11.56 / light 6.38
      secondary: c.action,
      onSecondary: c.onAction,
      secondaryContainer: c.actionBg,
      onSecondaryContainer: c.actionTx,
      tertiary: c.action,
      onTertiary: c.onAction,
      tertiaryContainer: c.actionBg,
      onTertiaryContainer: c.actionTx,
      error: c.urgent,
      // dark: slate900-on-red500 = 4.74 · light: white-on-red600 = 4.83
      onError: isDark ? c.onAction : Colors.white,
      errorContainer: c.urgentBg,
      onErrorContainer: c.urgentTx, // 8.51 / 6.80
      surface: c.surface,
      onSurface: c.text1, // 13.35 / 17.85
      onSurfaceVariant: c.text2, // 5.71 / 7.58
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.surfaceRaised,
      outline: c.borderStrong, // 3.63:1 — interactive edges
      outlineVariant: c.border, // subtle divider
      // Pin the inverse pair (SnackBars) so an SDK bump can't recolour it.
      inverseSurface: c.text1,
      onInverseSurface: c.background,
      surfaceTint: Colors.transparent, // kill M3 elevation tint
    );
  }

  /// Brand wordmark style — Inter Black 900. Use only for logo/wordmark text.
  /// Example: Text('JOBDUN', style: AppTheme.brandDisplay(context.c.text1))
  static TextStyle brandDisplay(Color color) => GoogleFonts.oswald(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: 3.0,
    color: color,
  );

  /// Default Pinput cell theme. Apply to Pinput.defaultPinTheme.
  static PinTheme pinputTheme(JColors c) => PinTheme(
    width: 56,
    height: 56,
    textStyle: GoogleFonts.oswald(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: c.text1,
    ),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadius.input),
      border: Border.all(color: c.border),
    ),
  );

  /// Focused Pinput cell theme. Apply to Pinput.focusedPinTheme.
  static PinTheme pinputFocusedTheme(JColors c) => PinTheme(
    width: 56,
    height: 56,
    textStyle: GoogleFonts.oswald(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: c.text1,
    ),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadius.input),
      border: Border.all(color: c.action, width: 2),
    ),
  );

  static ThemeData _build(JColors c, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = _scheme(c, brightness);

    final openSansBase = GoogleFonts.openSansTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );

    final textTheme = openSansBase.copyWith(
      displayLarge: GoogleFonts.oswald(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: c.text1,
      ),
      displaySmall: GoogleFonts.oswald(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: c.text1,
      ),
      headlineLarge: GoogleFonts.oswald(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: c.text1,
      ),
      headlineMedium: GoogleFonts.oswald(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: c.text1,
      ),
      headlineSmall: GoogleFonts.oswald(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: c.text1,
      ),
      titleLarge: GoogleFonts.oswald(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: c.text1,
      ),
      titleMedium: GoogleFonts.openSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.6,
        color: c.text1,
      ),
      bodyLarge: GoogleFonts.openSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: c.text1,
      ),
      bodyMedium: GoogleFonts.openSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.45, // comfortable leading on the most-used secondary body
        color: c.text2,
      ),
      bodySmall: GoogleFonts.openSans(
        fontSize: 12, // floor raised from 11 — 12 is the readable minimum
        fontWeight: FontWeight.w500,
        color: c.text2,
      ),
      labelLarge: GoogleFonts.oswald(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: c.text1,
      ),
      labelMedium: GoogleFonts.openSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: c.text2,
      ),
      labelSmall: GoogleFonts.openSans(
        fontSize:
            11, // floor raised from 10 — eyebrows/FieldLabel were too small
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: c.text3,
      ),
    );

    // Touch-target floor — 48dp on every tappable surface so WCAG 2.5.5
    // ("Target Size — Minimum: 44 CSS pixels") is satisfied globally.
    // MaterialTapTargetSize.padded is the Material 3 default; pinning it
    // here explicitly so it doesn't drift if a downstream theme override
    // forgets it. Every button theme below also sets minimumSize: 48×48
    // because Flutter's default `minimumSize` for OutlinedButton / TextButton
    // / FilledButton is 64×36 — below the floor — and Material's padded
    // tap-target only adds room around the hit-test, not the visible widget.
    const minTap = Size(48, 48);
    final tapWrapStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(minTap),
      tapTargetSize: MaterialTapTargetSize.padded,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: [c],
      scaffoldBackgroundColor: c.background,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: c.text1,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(minTap),
          tapTargetSize: MaterialTapTargetSize.padded,
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return c.action.withValues(alpha: 0.15);
            }
            if (states.contains(WidgetState.hovered)) {
              return c.action.withValues(alpha: 0.08);
            }
            return null;
          }),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: tapWrapStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: tapWrapStyle),
      textButtonTheme: TextButtonThemeData(style: tapWrapStyle),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(minTap),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: c.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: c.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: c.action, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: c.urgent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: c.urgent, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: c.border.withValues(alpha: 0.4)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: GoogleFonts.openSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: c.text3,
        ),
        floatingLabelStyle: GoogleFonts.openSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: c.action,
        ),
        hintStyle: GoogleFonts.openSans(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: c.text3,
        ),
        errorStyle: GoogleFonts.openSans(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: c.urgentTx,
        ),
        prefixIconColor: c.text3,
        suffixIconColor: c.text3,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.action,
        selectionColor: c.action.withValues(alpha: 0.32),
        selectionHandleColor: c.action,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.card)),
          side: BorderSide(color: c.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      // Best-practice icon default: 24dp (MASTER §210 nav) + the legible `text2`
      // for icons that don't set their own size/colour. Was `text3`, which can
      // dip below the 3:1 icon-contrast floor on raised surfaces. Matches the
      // vetted PreviewTheme default.
      iconTheme: IconThemeData(size: AppIconSize.nav, color: c.text2),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.background,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.action;
          return c.surface;
        }),
        side: BorderSide(color: c.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
    );
  }
}
