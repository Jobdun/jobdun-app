import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';

/// "or continue with" plus the three provider tiles, shared by /login and
/// /register.
///
/// Figma `JobDun-Screens` → Login (nodes 63:1815 / 63:1892) draws these as
/// 48dp circles rather than the rounded squares the app shipped. All three now
/// share ONE tile — same fill, same edge, same size — so the row reads as a
/// set of equals; the mock's solid-black Apple disc made it look like a
/// different kind of control. Only the marks differ, and only where a brand
/// requires it (Google's is multicolour by its own guidelines).
///
/// Apple only renders where it can actually work. It has no Android
/// configuration (no `webAuthenticationOptions`), so the tile failed on 100%
/// of Android taps until it was gated (live bug K10, 2026-08-18).
class AuthSsoRow extends StatelessWidget {
  const AuthSsoRow({
    super.key,
    required this.onGoogle,
    required this.onApple,
    required this.onPhone,
    required this.isBusy,
    this.keyPrefix = 'login',
  });

  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onPhone;
  final bool isBusy;

  /// Namespaces the widget keys so /login and /register tiles stay
  /// individually addressable in tests.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final showApple = kIsWeb || defaultTargetPlatform == TargetPlatform.iOS;

    return Column(
      children: [
        Text(
          'or continue with',
          style: tt.bodyMedium!.copyWith(
            fontSize: 14,
            height: 1.0,
            color: c.text3,
          ),
        ),
        Gap(AppSpacing.md.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AuthSsoTile(
              key: Key('$keyPrefix.sso.google'),
              provider: SsoProvider.google,
              onTap: onGoogle,
              isLoading: isBusy,
            ),
            Gap(AppSpacing.md.w),
            if (showApple) ...[
              AuthSsoTile(
                key: Key('$keyPrefix.sso.apple'),
                provider: SsoProvider.apple,
                onTap: onApple,
                isLoading: isBusy,
              ),
              Gap(AppSpacing.md.w),
            ],
            AuthSsoTile(
              key: Key('$keyPrefix.sso.phone'),
              provider: SsoProvider.phone,
              onTap: onPhone,
              isLoading: isBusy,
            ),
          ],
        ),
      ],
    );
  }
}

enum SsoProvider { google, apple, phone }

/// One 48dp circular provider tile.
class AuthSsoTile extends StatelessWidget {
  const AuthSsoTile({
    super.key,
    required this.provider,
    required this.onTap,
    required this.isLoading,
  });

  final SsoProvider provider;
  final VoidCallback onTap;
  final bool isLoading;

  static const double _tileSize = 48;
  static const double _iconSize = 24;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    // One tile for all three providers: same 48dp circle, same surface fill,
    // same `borderStrong` edge. Apple used to sit on a solid black disc, which
    // made it read as a different KIND of control next to the two outlined
    // ones. Apple's HIG governs the MARK, not the button ground — a black mark
    // on a light button is one of its approved styles — so the tile unifies
    // and the glyph goes theme-aware instead (see [_Glyph]).
    final label = switch (provider) {
      SsoProvider.google => 'Sign in with Google',
      SsoProvider.apple => 'Sign in with Apple',
      SsoProvider.phone => 'Continue with phone number',
    };

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: c.surface,
        shape: CircleBorder(side: BorderSide(color: c.borderStrong)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          child: SizedBox(
            width: _tileSize.r,
            height: _tileSize.r,
            child: Center(
              child: isLoading
                  ? SizedBox.square(
                      dimension: 18.r,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.text3,
                      ),
                    )
                  : _Glyph(provider: provider),
            ),
          ),
        ),
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.provider});

  final SsoProvider provider;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const size = AuthSsoTile._iconSize;

    return switch (provider) {
      SsoProvider.google => SvgPicture.asset(
        'lib/core/assets/icon-google-color.svg',
        width: size.r,
        height: size.r,
      ),
      // Apple HIG: the mark is black on a light button, white on a dark one.
      // `text1` resolves to exactly that in each theme, so the tile can stay
      // neutral and the mark stays compliant.
      SsoProvider.apple => SvgPicture.asset(
        'lib/core/assets/icon-apple.svg',
        width: size.r,
        height: size.r,
        colorFilter: ColorFilter.mode(c.text1, BlendMode.srcIn),
      ),
      // Ours, so it matches Apple's neutral rather than shouting in orange —
      // MASTER reserves the brand orange for CTAs and critical status, and a
      // provider glyph is neither.
      SsoProvider.phone => Icon(AppIcons.phone, size: size.r, color: c.text1),
    };
  }
}
