import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The "JOB·DUN" horizontal brand lockup — orange italic "JOB" beside the
/// chrome "DUN" license-plate badge.
///
/// Shipped as a transparent PNG (`logo-jobdun-lockup.png`) rather than the
/// source SVG: the artwork is a 5.4 MB Illustrator export carrying metallic
/// gradients + 150-odd embedded raster tiles that `flutter_svg` can't render
/// faithfully. The rasterised PNG is ~29 KB and pixel-accurate. The asset is
/// authored at 320 px tall so it stays crisp when scaled down to the display
/// height on 3× screens.
///
/// Self-coloured (orange + chrome on a dark plate) — do not tint. Sits on the
/// dark `#0F172A` canvas; the plate's bevel gives it enough separation.
class JobdunLockup extends StatelessWidget {
  const JobdunLockup({super.key, this.height});

  /// Rendered height in logical pixels. Width follows the 525:198 aspect ratio.
  /// Defaults to 64.
  final double? height;

  static const _asset = 'lib/core/assets/logo-jobdun-lockup.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _asset,
      height: height ?? 64.h,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Jobdun',
    );
  }
}
