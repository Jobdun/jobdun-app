import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum LogoVariant { full, mark }

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

  @override
  Widget build(BuildContext context) {
    final isFull = variant == LogoVariant.full;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final h = height ?? (isFull ? 32.h : 28.h);

    final asset = isFull
        ? (isDark ? _fullDark : _fullLight)
        : (isDark ? _markDark : _markLight);

    return SvgPicture.asset(
      asset,
      height: h,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
