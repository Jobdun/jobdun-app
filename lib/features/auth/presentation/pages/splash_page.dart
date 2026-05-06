import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/constants/app_constants.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/config/env.dart';
import '../providers/auth_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  Timer? _startupTimer;

  @override
  void initState() {
    super.initState();
    _startupTimer = Timer(const Duration(milliseconds: 900), _continue);
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    super.dispose();
  }

  void _continue() {
    if (!mounted) return;
    final authState = ref.read(authControllerProvider);

    if (!authState.isAuthenticated) {
      context.go('/login');
      return;
    }
    if (!authState.onboardingComplete) {
      context.go('/onboarding');
      return;
    }
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              SvgPicture.asset(
                'lib/core/assets/mark-jobdun.svg',
                width: 64.r,
                height: 64.r,
              ),
              Gap(20.h),
              Text(
                'JOBDUN',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 40.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text1,
                  letterSpacing: 0.02 * 40,
                ),
              ),
              Gap(8.h),
              Text(
                AppConstants.appTagline,
                style: GoogleFonts.barlow(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.text2,
                ),
              ),
              const Spacer(),
              if (!AppEnv.isSupabaseConfigured)
                _EnvChip(missingKeys: AppEnv.missingKeysSummary),
              Gap(16.h),
              _LoadingBar(),
              Gap(24.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnvChip extends StatelessWidget {
  const _EnvChip({required this.missingKeys});

  final String missingKeys;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.chip.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.info_circle, size: 14.r, color: AppColors.text3),
          Gap(6.w),
          Flexible(
            child: Text(
              'Missing $missingKeys. Run with --dart-define-from-file=.env.',
              style: GoogleFonts.barlow(
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.text2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        builder: (context, value, _) {
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.action,
                borderRadius: BorderRadius.circular(999.r),
              ),
            ),
          );
        },
      ),
    );
  }
}
