import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/app_colors.dart';
import '../providers/auth_provider.dart';

/// Demoted SSO row: "Or continue with  Google · Apple" — 12sp text links.
/// No large brand buttons — Jobdun owns the auth experience.
class SocialAuthButtons extends ConsumerWidget {
  const SocialAuthButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final isLoading = ref.watch(
      authControllerProvider.select((s) => s.isLoading),
    );

    final baseStyle = tt.bodySmall!.copyWith(color: c.text3, fontSize: 12.sp);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Or continue with ', style: baseStyle),
        _SsoTextLink(
          svgAsset: 'lib/core/assets/icon-google.svg',
          label: 'Google',
          isLoading: isLoading,
          onTap: () =>
              ref.read(authControllerProvider.notifier).signInWithGoogle(),
        ),
        Text(' · ', style: baseStyle),
        _SsoTextLink(
          svgAsset: 'lib/core/assets/icon-apple.svg',
          label: 'Apple',
          isLoading: isLoading,
          onTap: () =>
              ref.read(authControllerProvider.notifier).signInWithApple(),
        ),
      ],
    );
  }
}

class _SsoTextLink extends StatelessWidget {
  const _SsoTextLink({
    required this.svgAsset,
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  final String svgAsset;
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedOpacity(
        opacity: isLoading ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              svgAsset,
              width: 13.r,
              height: 13.r,
              colorFilter: ColorFilter.mode(c.text2, BlendMode.srcIn),
            ),
            Gap(4.w),
            Text(
              label,
              style: tt.bodySmall!.copyWith(
                color: c.text2,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
