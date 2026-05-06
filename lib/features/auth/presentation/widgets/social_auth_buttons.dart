import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class SocialAuthButtons extends ConsumerWidget {
  const SocialAuthButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      authControllerProvider.select((s) => s.isLoading),
    );

    return Column(
      children: [
        const _OrDivider(),
        Gap(16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialButton(
              loading: isLoading,
              onPressed: isLoading
                  ? null
                  : () => ref
                      .read(authControllerProvider.notifier)
                      .signInWithGoogle(),
              child: SvgPicture.asset(
                'lib/core/assets/icon-google.svg',
                width: 20.r,
                height: 20.r,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF4285F4),
                  BlendMode.srcIn,
                ),
              ),
            ),
            Gap(12.w),
            _SocialButton(
              loading: isLoading,
              onPressed: isLoading
                  ? null
                  : () => ref
                      .read(authControllerProvider.notifier)
                      .signInWithApple(),
              child: SvgPicture.asset(
                'lib/core/assets/icon-apple.svg',
                width: 20.r,
                height: 20.r,
                colorFilter: const ColorFilter.mode(
                  Colors.black87,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.loading,
    required this.onPressed,
    required this.child,
  });

  final bool loading;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48.r,
      height: 48.r,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.card,
          side: const BorderSide(color: AppColors.border),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.btn.r),
          ),
        ),
        child: loading
            ? SizedBox(
                width: 18.r,
                height: 18.r,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.action,
                ),
              )
            : child,
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Text(
            'or continue with',
            style: GoogleFonts.barlow(
              fontSize: 11.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.text3,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
