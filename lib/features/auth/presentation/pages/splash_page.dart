import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../app/constants/app_constants.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_gradients.dart';
import '../../../../core/config/env.dart';
import '../../../../core/design/widgets/jobdun_logo.dart';

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
    // Route to '/', not '/home' — lets the router redirect decide where the
    // user actually lands based on auth state (login / verify-email / home).
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            children: [
              const Spacer(),
              JobdunLogo(variant: LogoVariant.mark, height: 64.r),
              Gap(20.h),
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppGradients.brandFlame.createShader(bounds),
                child: Text(
                  'JOBDUN',
                  style: tt.displaySmall!.copyWith(
                    fontSize: 48.sp,
                    letterSpacing: 4.0,
                    height: 1.0,
                    color: Colors
                        .white, // intentional: ShaderMask requires white for gradient
                  ),
                ),
              ),
              Gap(6.h),
              Text(
                AppConstants.appTagline,
                style: tt.bodyMedium!.copyWith(
                  color: c.text3,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              if (!AppEnv.isSupabaseConfigured)
                _EnvChip(missingKeys: AppEnv.missingKeysSummary),
              Gap(AppSpacing.md.h),
              _LoadingBar(c: c),
              Gap(AppSpacing.lg.h),
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
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.chip.r),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.info, size: AppIconSize.xs.r, color: c.text3),
          Gap(6.w),
          Flexible(
            child: Text(
              'Missing $missingKeys. Run with --dart-define-from-file=.env.',
              style: tt.bodySmall!.copyWith(color: c.text2),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.c});

  final JColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface,
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
                color: c.action,
                borderRadius: BorderRadius.circular(999.r),
              ),
            ),
          );
        },
      ),
    );
  }
}
