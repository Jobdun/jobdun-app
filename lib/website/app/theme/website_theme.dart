import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_typography.dart';

/// Marketing-site theme: the shared [AppTheme] (colours, buttons, spacing,
/// borders) with its type swapped to the **Archivo + Inter** website scale
/// ([WebsiteText]).
///
/// Scoped to the website on purpose. The mobile app now shares this family
/// pairing through [AppTypography], while admin keeps its own desktop scale.
/// Only `lib/website/app/website_app.dart` builds with this theme.
abstract final class WebsiteTheme {
  static ThemeData light() => _withType(AppTheme.light(), JColors.light);
  static ThemeData dark() => _withType(AppTheme.dark(), JColors.dark);

  static ThemeData _withType(ThemeData base, JColors c) {
    final textTheme = WebsiteText.textTheme(
      text1: c.text1,
      text2: c.text2,
      text3: c.text3,
    );
    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        labelStyle: WebsiteText.inputLabel(c.text3),
        floatingLabelStyle: WebsiteText.inputLabel(c.action),
        hintStyle: WebsiteText.inputHint(c.text3),
        errorStyle: WebsiteText.inputError(c.urgentTx),
      ),
    );
  }
}
