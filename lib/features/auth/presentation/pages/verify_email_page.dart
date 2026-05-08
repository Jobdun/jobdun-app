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
    final c = context.c;
    final authState = ref.watch(authControllerProvider);
    final email = authState.pendingVerificationEmail ?? '';

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Brand mark ──────────────────────────────────────────────────
              Gap(48.h),
              Center(
                child: SvgPicture.asset(
                  'lib/core/assets/mark-jobdun.svg',
                  width: 52.r,
                  height: 52.r,
                  colorFilter: ColorFilter.mode(c.action, BlendMode.srcIn),
                ),
              ),
              Gap(12.h),
              Center(
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFF176),
                      Color(0xFFFFB300),
                      Color(0xFFF97316),
                      Color(0xFFE64A19),
                      Color(0xFFBF360C),
                    ],
                    stops: [0.0, 0.2, 0.5, 0.75, 1.0],
                  ).createShader(bounds),
                  child: Text(
                    'JOBDUN',
                    style: GoogleFonts.oswald(
                      fontSize: 44.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4.0,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
              ),

              Gap(48.h),

              // ── Email icon ────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 80.r,
                  height: 80.r,
                  decoration: BoxDecoration(
                    color: c.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadius.card.r),
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(
                    Iconsax.sms_notification,
                    size: 36.r,
                    color: c.action,
                  ),
                ),
              ),

              Gap(28.h),

              // ── Heading ───────────────────────────────────────────────────
              Text(
                'CHECK YOUR\nEMAIL.',
                style: GoogleFonts.oswald(
                  fontSize: 40.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: c.text1,
                  height: 1.05,
                ),
              ),
              Gap(12.h),
              Text.rich(
                TextSpan(
                  style: GoogleFonts.openSans(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: c.text2,
                    height: 1.7,
                  ),
                  children: [
                    const TextSpan(text: 'We sent a verification link to '),
                    TextSpan(
                      text: email,
                      style: GoogleFonts.openSans(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: c.action,
                      ),
                    ),
                    const TextSpan(text: '. Tap it to activate your account.'),
                  ],
                ),
              ),

              Gap(12.h),

              // ── Tips row ──────────────────────────────────────────────────
              Container(
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card.r),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Iconsax.info_circle, size: 16.r, color: c.text3),
                    Gap(10.w),
                    Expanded(
                      child: Text(
                        "Can't find it? Check your spam or junk folder.",
                        style: GoogleFonts.openSans(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          color: c.text3,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (authState.infoMessage != null) ...[
                Gap(12.h),
                StatusBanner(
                  message: authState.infoMessage!,
                  isError: false,
                ),
              ],
              if (authState.errorMessage != null) ...[
                Gap(12.h),
                StatusBanner(
                  message: authState.errorMessage!,
                  isError: true,
                ),
              ],

              Gap(32.h),

              AppButton(
                label: authState.isLoading
                    ? 'Sending...'
                    : 'Resend verification email',
                isLoading: authState.isLoading,
                onPressed: authState.isLoading
                    ? null
                    : () => ref
                        .read(authControllerProvider.notifier)
                        .resendVerificationEmail(),
              ),

              Gap(12.h),

              Row(
                children: [
                  Expanded(child: Divider(color: c.border)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Text(
                      'OR',
                      style: GoogleFonts.openSans(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        color: c.text3,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: c.border)),
                ],
              ),

              Gap(12.h),

              AppButton(
                label: 'Back to sign in',
                variant: AppButtonVariant.secondary,
                onPressed: () => ref
                    .read(authControllerProvider.notifier)
                    .clearPendingVerification(),
              ),

              Gap(32.h),
            ],
          ),
        ),
      ),
    );
  }
}
