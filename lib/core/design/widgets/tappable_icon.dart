import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../app/constants/app_constants.dart';
import 'adaptive_icon.dart';

/// An icon-only tap target with a guaranteed minimum hit area.
///
/// The drawn glyph stays at its semantic [glyphSize]; the interactive area is
/// expanded to at least [AppTouchTarget.min] (44pt iOS / 48dp Android) so it
/// always satisfies the platform accessibility minimum, regardless of glyph
/// size. Exposes a labeled button to the semantics tree for screen readers.
///
/// Use this instead of a bare `IconButton` / `GestureDetector(child: Icon(...))`
/// for any tappable icon. Composes [AdaptiveIcon] so an iOS-specific glyph can
/// be supplied via [cupertino].
class TappableIcon extends StatelessWidget {
  const TappableIcon({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.cupertino,
    this.glyphSize = AppIconSize.md,
    this.color,
  });

  /// Default (Material/Iconsax) glyph.
  final IconData icon;

  /// Optional iOS-specific glyph (see [AdaptiveIcon]).
  final IconData? cupertino;

  /// Accessibility label — required; an icon-only control is meaningless to a
  /// screen reader without one.
  final String semanticLabel;

  /// Tap handler. `null` renders a disabled (non-tappable) state.
  final VoidCallback? onTap;

  /// Drawn glyph size in logical px (before `.r`). Defaults to
  /// [AppIconSize.md]; the hit area does not shrink with it.
  final double glyphSize;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final min = AppTouchTarget.min;
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: onTap != null,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        radius: min / 2,
        containedInkWell: false,
        canRequestFocus: false,
        excludeFromSemantics: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: min, minHeight: min),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: AdaptiveIcon(
              iconsax: icon,
              cupertino: cupertino,
              size: glyphSize.r,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
