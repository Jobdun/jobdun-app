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
    final c = context.c;
    final isLoading = ref.watch(
      authControllerProvider.select((s) => s.isLoading),
    );

    return Column(
      children: [
        Text(
          'OR CONTINUE WITH',
          style: GoogleFonts.barlow(
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.12 * 10,
            color: c.text3,
          ),
        ),
        Gap(10.h),
        Row(
          children: [
            _SocialChip(
              icon: 'lib/core/assets/icon-google.svg',
              label: 'Google',
              isLoading: isLoading,
              onTap: () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
            ),
            Gap(10.w),
            _SocialChip(
              icon: 'lib/core/assets/icon-apple.svg',
              label: 'Apple',
              isLoading: isLoading,
              onTap: () => ref.read(authControllerProvider.notifier).signInWithApple(),
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialChip extends StatelessWidget {
  const _SocialChip({
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Expanded(
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: AnimatedOpacity(
          opacity: isLoading ? 0.4 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            height: 40.h,
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.btn.r),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(icon, width: 16.r, height: 16.r),
                Gap(8.w),
                Text(
                  label,
                  style: GoogleFonts.barlow(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: c.text1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
