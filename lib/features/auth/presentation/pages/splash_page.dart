import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/config/env.dart';
import '../../../../core/design/colors.dart';
import 'splash_widgets/splash_shutter.dart';

/// Cold-start screen. Everything visible here is [SplashShutter] — the brand
/// animation that carries the orange launch screen through to the settled
/// JOBDUN lockup. Navigation waits on the animation's own completion callback
/// rather than a parallel timer, so the two can't drift apart.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _navigated = false;

  void _continue() {
    // `whenComplete` can fire alongside a reduced-motion post-frame settle;
    // the latch keeps a double-fire from pushing two routes.
    if (!mounted || _navigated) return;
    _navigated = true;
    // Route to '/', not '/home' — lets the router redirect decide where the
    // user actually lands based on auth state (login / verify-email / home).
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: SplashShutter(onSettled: _continue)),
          if (!AppEnv.isSupabaseConfigured)
            Positioned(
              left: 20.w,
              right: 20.w,
              bottom: 0,
              child: SafeArea(
                child: _EnvChip(missingKeys: AppEnv.missingKeysSummary),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dev-only diagnostic: a build launched without Supabase credentials cannot
/// sign anyone in, so it says so loudly instead of failing at the login screen.
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
          Icon(AppIcons.info, size: AppIconSize.micro.r, color: c.text3),
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
