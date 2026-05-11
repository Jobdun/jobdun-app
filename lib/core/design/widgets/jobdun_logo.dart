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

  /// Widget height in logical pixels. Defaults to 32 (full) or 28 (mark),
  /// scaled with flutter_screenutil when the library is active.
  final double? height;

  /// Tints the SVG with [ColorFilter.mode(color, BlendMode.srcIn)].
  /// Leave null to render the original SVG colours.
  final Color? color;

  static const _assetFull = 'lib/core/assets/logo-jobdun.svg';
  static const _assetMark = 'lib/core/assets/mark-jobdun.svg';

  @override
  Widget build(BuildContext context) {
    final isFull = variant == LogoVariant.full;
    final h = height ?? (isFull ? 32.h : 28.h);

    return SvgPicture.asset(
      isFull ? _assetFull : _assetMark,
      height: h,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
