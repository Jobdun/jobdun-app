import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// - [full]  horizontal lockup (mark + JOBDUN wordmark), brightness-adaptive.
/// - [mark]  the bare glyph on a transparent ground, brightness-adaptive.
/// - [badge] the universal app-icon badge — orange circle, white mark.
///           Self-contained colour; reads on any background. Leave [color] null.
enum LogoVariant { full, mark, badge }

class JobdunLogo extends StatelessWidget {
  const JobdunLogo({
    super.key,
    this.variant = LogoVariant.full,
    this.height,
    this.color,
  });

  final LogoVariant variant;

  /// Widget height in logical pixels. Defaults to 32 (full) or 28 (mark).
  final double? height;

  /// Force a flat tint over the entire SVG (e.g. white-on-orange surfaces).
  /// Leave null to use the built-in adaptive dark/light colours.
  final Color? color;

  static const _markDark = 'lib/core/assets/mark-jobdun.svg';
  static const _markLight = 'lib/core/assets/mark-jobdun-light.svg';
  static const _fullDark = 'lib/core/assets/logo-jobdun.svg';
  static const _fullLight = 'lib/core/assets/logo-jobdun-light.svg';
  static const _badge = 'lib/core/assets/badge-jobdun.svg';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final h =
        height ??
        switch (variant) {
          LogoVariant.full => 32.h,
          LogoVariant.mark => 28.h,
          LogoVariant.badge => 32.h,
        };

    final asset = switch (variant) {
      LogoVariant.full => isDark ? _fullDark : _fullLight,
      LogoVariant.mark => isDark ? _markDark : _markLight,
      LogoVariant.badge => _badge,
    };

    return SvgPicture.asset(
      asset,
      height: h,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
