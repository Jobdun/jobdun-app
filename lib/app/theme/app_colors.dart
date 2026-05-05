import 'package:flutter/material.dart';

// Swap these out when the design system arrives.
// app_theme.dart and widgets reference these tokens, not raw hex values.
abstract final class AppColors {
  // Brand
  static const seedOrange = Color(0xFFC96C2D);
  static const primary = Color(0xFFB8561C);
  static const secondary = Color(0xFF254441);

  // Surfaces
  static const background = Color(0xFFF3EEE7);
  static const surface = Color(0xFFF7F3EE);
  static const cardBackground = Colors.white;

  // Borders & dividers
  static const border = Color(0xFFE2D6C8);

  // Text
  static const textMuted = Color(0xFF5A5A5A);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 18.0;
  static const xl = 24.0;
}
