import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.foundation,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.foundation,
      onPrimary: Colors.white,
      primaryContainer: AppColors.actionBg,
      onPrimaryContainer: AppColors.actionTx,
      secondary: AppColors.action,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.actionBg,
      onSecondaryContainer: AppColors.actionTx,
      tertiary: AppColors.verified,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.verifiedBg,
      onTertiaryContainer: AppColors.verifiedTx,
      error: AppColors.urgent,
      onError: Colors.white,
      errorContainer: AppColors.urgentBg,
      onErrorContainer: AppColors.urgentTx,
      surface: AppColors.card,
      onSurface: AppColors.text1,
      surfaceContainerHighest: AppColors.surface,
      onSurfaceVariant: AppColors.text2,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      inverseSurface: AppColors.foundation,
      onInverseSurface: Colors.white,
    );

    final barlowBase = GoogleFonts.barlowTextTheme();

    final textTheme = barlowBase.copyWith(
      displayLarge: GoogleFonts.barlowCondensed(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.02 * 57,
      ),
      displayMedium: GoogleFonts.barlowCondensed(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.02 * 45,
      ),
      displaySmall: GoogleFonts.barlowCondensed(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.02 * 40,
      ),
      headlineLarge: GoogleFonts.barlowCondensed(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.02 * 28,
      ),
      headlineMedium: GoogleFonts.barlow(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.barlow(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.barlow(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.barlow(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.7,
      ),
      bodyLarge: GoogleFonts.barlow(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.7,
      ),
      bodyMedium: GoogleFonts.barlow(
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: GoogleFonts.barlow(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: GoogleFonts.barlow(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.01 * 13,
      ),
      labelMedium: GoogleFonts.barlow(
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
      labelSmall: GoogleFonts.barlow(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.12 * 11,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.foundation, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.urgent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.urgent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: GoogleFonts.barlow(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.text3,
        ),
        hintStyle: GoogleFonts.barlow(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.text3,
        ),
        errorStyle: GoogleFonts.barlow(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: AppColors.urgent,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.text2),
    );
  }
}
