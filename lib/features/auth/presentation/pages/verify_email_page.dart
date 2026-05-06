import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/status_banner.dart';
import '../providers/auth_provider.dart';

class VerifyEmailPage extends ConsumerWidget {
  const VerifyEmailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final email = authState.pendingVerificationEmail ?? '';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Gap(32.h),
              Center(
                child: SvgPicture.asset(
                  'lib/core/assets/mark-jobdun.svg',
                  width: 40.r,
                  height: 40.r,
                ),
              ),
              const Spacer(),
              Container(
                width: 72.r,
                height: 72.r,
                decoration: BoxDecoration(
                  color: AppColors.foundation,
                  borderRadius: BorderRadius.circular(AppRadius.avatar.r),
                ),
                child: Icon(
                  Iconsax.sms_notification,
                  size: 36.r,
                  color: Colors.white,
                ),
              ),
              Gap(24.h),
              Text(
                'CHECK YOUR EMAIL',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.02 * 28,
                  color: AppColors.text1,
                ),
              ),
              Gap(12.h),
              Text.rich(
                TextSpan(
                  style: GoogleFonts.barlow(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.text2,
                    height: 1.7,
                  ),
                  children: [
                    const TextSpan(text: 'We sent a verification link to '),
                    TextSpan(
                      text: email,
                      style: GoogleFonts.barlow(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.action,
                      ),
                    ),
                    const TextSpan(
                      text: '. Tap it to verify your account.',
                    ),
                  ],
                ),
              ),
              if (authState.infoMessage != null) ...[
                Gap(12.h),
                StatusBanner(message: authState.infoMessage!, isError: false),
              ],
              if (authState.errorMessage != null) ...[
                Gap(12.h),
                StatusBanner(message: authState.errorMessage!, isError: true),
              ],
              const Spacer(),
              AppButton(
                label: authState.isLoading
                    ? 'Sending...'
                    : 'Resend verification email',
                variant: AppButtonVariant.ghost,
                isLoading: authState.isLoading,
                onPressed: authState.isLoading
                    ? null
                    : () => ref
                        .read(authControllerProvider.notifier)
                        .resendVerificationEmail(),
              ),
              Gap(12.h),
              AppButton(
                label: 'Back to sign in',
                variant: AppButtonVariant.text,
                onPressed: () => ref
                    .read(authControllerProvider.notifier)
                    .clearPendingVerification(),
              ),
              Gap(16.h),
            ],
          ),
        ),
      ),
    );
  }
}
