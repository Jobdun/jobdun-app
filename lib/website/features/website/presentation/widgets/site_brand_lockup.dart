import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../app/theme/app_theme.dart';
import '../../../../../core/design/colors.dart';

/// Horizontal brand lockup for the site chrome: the hammer-J app-icon badge
/// followed by the JOBDUN wordmark set in Oswald — the brand display face.
///
/// The badge reproduces the launcher icon exactly (white hammer-J on a
/// safety-orange rounded square, `mark-jobdun.svg` carrying the icon's native
/// inset), so the header mark, the app icon, and the registered trademark all
/// read as one identity. The wordmark is live text — it inherits the active
/// theme so it stays crisp and recolours with light/dark instead of baking a
/// flat SVG.
class SiteBrandLockup extends StatelessWidget {
  const SiteBrandLockup({super.key, this.height = 34});

  /// Badge edge length in logical pixels; the wordmark scales from it.
  final double height;

  static const _mark = 'lib/core/assets/mark-jobdun.svg';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: height,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height * 0.28),
            child: ColoredBox(
              color: c.action,
              child: SvgPicture.asset(
                _mark,
                fit: BoxFit.contain,
                colorFilter: const ColorFilter.mode(
                  Colors
                      .white, // intentional: matches the white-on-orange app icon
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: height * 0.34),
        Text(
          'JOBDUN',
          style: AppTheme.brandDisplay(
            c.text1,
          ).copyWith(fontSize: height * 0.66, letterSpacing: 1.2, height: 1.0),
        ),
      ],
    );
  }
}
