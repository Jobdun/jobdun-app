import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../app/theme/app_colors.dart';

/// Compact icon button used for Google / Apple / Phone auth entry points on
/// /login. Renders a 56x56 rounded-square tile with the brand mark inside.
///
/// Sits in a centred Row of three peers — same visual weight, brand colours
/// preserved (multi-colour Google G, white Apple, neutral phone). Aligns
/// with the Aggressive-Flat aesthetic in MASTER.md: 8px radius, surface
/// background, 1px border, no shadow.
class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton({
    super.key,
    required this.iconBuilder,
    this.caption,
    required this.onTap,
    this.isLoading = false,
    this.semanticsLabel,
  });

  /// Google — official multi-colour G mark. No caption: Jakob's Law says the
  /// G mark is universally recognised; the label is redundant noise.
  const SocialAuthButton.google({
    super.key,
    required VoidCallback this.onTap,
    this.isLoading = false,
  }) : iconBuilder = _googleIcon,
       caption = null,
       semanticsLabel = 'Continue with Google';

  /// Apple — white logo (Apple HIG forbids tinting). No caption for the same
  /// reason as Google — universally recognised brand mark.
  const SocialAuthButton.apple({
    super.key,
    required VoidCallback this.onTap,
    this.isLoading = false,
  }) : iconBuilder = _appleIcon,
       caption = null,
       semanticsLabel = 'Continue with Apple';

  /// Phone — Iconsax call glyph. No caption: matches Google/Apple peers for
  /// a clean icon-only row; screen readers still get the semantics label.
  const SocialAuthButton.phone({
    super.key,
    required VoidCallback this.onTap,
    this.isLoading = false,
  }) : iconBuilder = _phoneIcon,
       caption = null,
       semanticsLabel = 'Continue with phone number';

  /// Returns the icon widget for this button. A function (not a Widget) so
  /// the constructor can stay const and each variant can read context.c.
  final Widget Function(BuildContext) iconBuilder;

  /// Optional caption rendered under the icon tile. null = icon only.
  final String? caption;
  final VoidCallback? onTap;
  final bool isLoading;
  final String? semanticsLabel;

  static const double _tileSize = 56;
  static const double _iconSize = 28;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final disabled = onTap == null || isLoading;

    final tile = Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadius.card.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: disabled ? null : onTap,
        child: Ink(
          width: _tileSize.r,
          height: _tileSize.r,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            border: Border.all(color: c.border),
          ),
          child: Center(
            child: isLoading
                ? SizedBox.square(
                    dimension: 18.r,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.text1,
                    ),
                  )
                : iconBuilder(context),
          ),
        ),
      ),
    );

    // When there is no caption, wrap the tile in a Semantics so screen
    // readers still announce the button — without a visible label there's
    // no other source for accessible naming.
    if (caption == null) {
      return Semantics(
        button: true,
        label: semanticsLabel,
        excludeSemantics: true,
        child: tile,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tile,
        Gap(AppSpacing.xs.h),
        Text(
          caption!,
          style: tt.bodySmall!.copyWith(color: c.text2, fontSize: 11.sp),
          semanticsLabel: semanticsLabel,
        ),
      ],
    );
  }

  static Widget _googleIcon(BuildContext context) => SvgPicture.asset(
    'lib/core/assets/icon-google-color.svg',
    width: _iconSize.r,
    height: _iconSize.r,
  );

  static Widget _appleIcon(BuildContext context) => SvgPicture.asset(
    'lib/core/assets/icon-apple.svg',
    width: _iconSize.r,
    height: _iconSize.r,
    colorFilter: ColorFilter.mode(
      context.c.text1, // white on dark, per Apple HIG monochrome rule
      BlendMode.srcIn,
    ),
  );

  static Widget _phoneIcon(BuildContext context) =>
      Icon(AppIcons.phone, size: _iconSize.r, color: context.c.text1);
}
