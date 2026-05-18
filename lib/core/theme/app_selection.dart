import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Selection-state tokens for navigation chrome (bottom-nav tabs).
///
/// Single source of truth for the active/inactive icon + label treatment so
/// the Trade and (later) Builder navs stay visually identical and animate the
/// same way. Role-specific to the nav — not a global type/color change.
abstract final class AppSelection {
  /// Tab state transition (color + weight tween). Matches MASTER motion spec
  /// (150–200ms ease, no bounce).
  static const duration = Duration(milliseconds: 150);
  static const curve = Curves.easeOut;

  /// Label weight reinforces the outline→Bold icon variant swap.
  static const activeWeight = FontWeight.w700;
  static const inactiveWeight = FontWeight.w600;

  /// Active tab = safety orange (reinforces selection alongside the icon).
  static Color activeColor(JColors c) => c.action;

  /// Inactive tab = muted slate (quiet, recedes).
  static Color inactiveColor(JColors c) => c.text3;
}
