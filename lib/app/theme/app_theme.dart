import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  // Light theme is intentionally private — app is dark-only.
  // Do NOT pass AppTheme._light() to MaterialApp.theme.
  // ignore: unused_element
  static ThemeData _light() => _build(JColors.light, Brightness.light);
  static ThemeData dark()   => _build(JColors.dark,  Brightness.dark);

  /// Brand wordmark style — Inter Black 900. Use only for logo/wordmark text.
  /// Example: Text('JOBDUN', style: AppTheme.brandDisplay(context.c.text1))
  static TextStyle brandDisplay(Color color) => GoogleFonts.inter(
    fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 3.0, color: color,
  );

  /// Default Pinput cell theme. Apply to Pinput.defaultPinTheme.
  static PinTheme pinputTheme(JColors c) => PinTheme(
    width: 56,
    height: 56,
    textStyle: GoogleFonts.oswald(
      fontSize: 20, fontWeight: FontWeight.w700, color: c.text1,
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
      fontSize: 20, fontWeight: FontWeight.w700, color: c.text1,
    ),
    decoration: BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadius.input),
      border: Border.all(color: c.action, width: 2),
    ),
  );

  static ThemeData _build(JColors c, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary:              c.action,
      onPrimary:            Colors.white, // intentional: white-on-action
      primaryContainer:     c.actionBg,
      onPrimaryContainer:   c.actionTx,
      secondary:            c.surfaceRaised,
      onSecondary:          c.text1,
      secondaryContainer:   c.surface,
      onSecondaryContainer: c.text2,
      tertiary:             c.verified,
      onTertiary:           Colors.white, // intentional: white-on-action
      tertiaryContainer:    c.verifiedBg,
      onTertiaryContainer:  c.verifiedTx,
      error:                c.urgent,
      onError:              Colors.white, // intentional: white-on-action
      errorContainer:       c.urgentBg,
      onErrorContainer:     c.urgentTx,
      surface:              c.card,
      onSurface:            c.text1,
      surfaceContainerHighest: c.surface,
      onSurfaceVariant:     c.text2,
      outline:              c.border,
      outlineVariant:       c.border,
      inverseSurface:       isDark ? c.text1 : c.text1,
      onInverseSurface:     isDark ? c.background : c.background,
    );

    final openSansBase = GoogleFonts.openSansTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );

    final textTheme = openSansBase.copyWith(
      displayLarge: GoogleFonts.oswald(
        fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: c.text1,
      ),
      displaySmall: GoogleFonts.oswald(
        fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: c.text1,
      ),
      headlineLarge: GoogleFonts.oswald(
        fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: c.text1,
      ),
      headlineMedium: GoogleFonts.oswald(
        fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: c.text1,
      ),
      headlineSmall: GoogleFonts.oswald(
        fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.3, color: c.text1,
      ),
      titleLarge: GoogleFonts.oswald(
        fontSize: 16, fontWeight: FontWeight.w600, color: c.text1,
      ),
      titleMedium: GoogleFonts.openSans(
        fontSize: 15, fontWeight: FontWeight.w600, height: 1.6, color: c.text1,
      ),
      bodyLarge: GoogleFonts.openSans(
        fontSize: 15, fontWeight: FontWeight.w400, height: 1.6, color: c.text1,
      ),
      bodyMedium: GoogleFonts.openSans(
        fontSize: 13, fontWeight: FontWeight.w400, color: c.text2,
      ),
      bodySmall: GoogleFonts.openSans(
        fontSize: 11, fontWeight: FontWeight.w500, color: c.text2,
      ),
      labelLarge: GoogleFonts.oswald(
        fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: c.text1,
      ),
      labelMedium: GoogleFonts.openSans(
        fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: c.text2,
      ),
      labelSmall: GoogleFonts.openSans(
        fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: c.text3,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: [c],
      scaffoldBackgroundColor: c.background,
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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: c.border),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: GoogleFonts.openSans(
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: c.text3,
        ),
        floatingLabelStyle: GoogleFonts.openSans(
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: c.action,
        ),
        hintStyle: GoogleFonts.openSans(
          fontSize: 13, fontWeight: FontWeight.w400, color: c.text3,
        ),
        errorStyle: GoogleFonts.openSans(
          fontSize: 11, fontWeight: FontWeight.w500, color: c.urgentTx,
        ),
        prefixIconColor: c.text3,
        suffixIconColor: c.text3,
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
      iconTheme: IconThemeData(color: c.text3),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.background,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.action;
          return c.surface;
        }),
        side: BorderSide(color: c.border, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
