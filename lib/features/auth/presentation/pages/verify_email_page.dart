import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/design/widgets/animated_empty_glyph.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/jobdun_logo.dart';
import '../../../../core/widgets/status_banner.dart';
import '../providers/auth_provider.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _resend() {
    ref.read(authControllerProvider.notifier).resendVerificationEmail();
    _startCooldown();
  }

  Future<void> _checkVerified() async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .checkEmailVerified();
    // On success, clearing pendingVerificationEmail flips the router redirect
    // → user lands on /home automatically. Nothing else to do here.
    if (ok && mounted) {
      // No-op: redirect handles navigation.
    }
  }

  void _changeEmail() {
    // Keep the registerDraft so /register can pre-fill the form, but drop
    // the verification gate so the router doesn't pull the user straight back.
    ref.read(authControllerProvider.notifier).clearPendingVerification();
    context.go('/register');
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) timer.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final authState = ref.watch(authControllerProvider);
    final email = authState.pendingVerificationEmail ?? '';
    final onCooldown = _cooldownSeconds > 0;
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Compact wordmark — user is mid-flow, they know the app.
              // Full lockup is reserved for splash + login (T3.2).
              Gap(24.h),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    JobdunLogo(variant: LogoVariant.mark, height: 24.r),
                    Gap(8.w),
                    Text(
                      'JOBDUN',
                      style: AppTheme.brandDisplay(
                        c.text1,
                      ).copyWith(fontSize: 18.sp, letterSpacing: 1.5),
                    ),
                  ],
                ),
              ),

              Gap(32.h),

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
                  child: AnimatedEmptyGlyph(
                    icon: AppIcons.emailNotification,
                    motion: EmptyGlyphMotion.float,
                    size: AppIconSize.feature.r,
                    color: c.actionInk,
                  ),
                ),
              ),

              Gap(28.h),

              // ── Heading ───────────────────────────────────────────────────
              Text(
                'CHECK YOUR\nEMAIL.',
                style: tt.displaySmall!.copyWith(
                  fontSize: 40.sp,
                  letterSpacing: 0.8,
                  color: c.text1,
                  height: 1.05,
                ),
              ),
              Gap(12.h),
              Text.rich(
                TextSpan(
                  style: tt.bodyLarge!.copyWith(
                    color: c.text2,
                    fontSize: 14.sp,
                    height: 1.7,
                  ),
                  children: [
                    const TextSpan(text: 'Verification link sent to '),
                    TextSpan(
                      text: email,
                      style: tt.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.actionInk,
                        fontSize: 14.sp,
                      ),
                    ),
                    const TextSpan(text: '. Tap it to activate your account.'),
                  ],
                ),
              ),

              Gap(12.h),

              // ── Tips ──────────────────────────────────────────────────────
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
                    Icon(
                      AppIcons.info,
                      size: AppIconSize.inline.r,
                      color: c.text3,
                    ),
                    Gap(10.w),
                    Expanded(
                      child: Text(
                        "Can't find it? Check your spam or junk folder.",
                        style: tt.labelMedium!.copyWith(
                          color: c.text3,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Status banners ────────────────────────────────────────────
              if (authState.infoMessage != null) ...[
                Gap(12.h),
                StatusBanner(message: authState.infoMessage!, isError: false),
              ],
              if (authState.errorMessage != null) ...[
                Gap(12.h),
                StatusBanner(message: authState.errorMessage!, isError: true),
              ],

              Gap(AppSpacing.xl.h),

              // ── Primary CTA: "I've verified — continue" ──────────────────
              // Closes the email-link round-trip into an in-app tap. Pulls a
              // fresh session, checks emailConfirmedAt, routes to /home on ok.
              JButton(
                label: isLoading ? 'CHECKING...' : "I'VE VERIFIED — CONTINUE",
                isLoading: isLoading,
                onPressed: isLoading ? null : _checkVerified,
              ),

              Gap(12.h),

              // ── Resend — disabled during cooldown ─────────────────────────
              JButton(
                label: onCooldown
                    ? 'RESEND IN ${_cooldownSeconds}S'
                    : 'RESEND VERIFICATION EMAIL',
                variant: JButtonVariant.secondary,
                onPressed: (isLoading || onCooldown) ? null : _resend,
              ),

              Gap(AppSpacing.md.h),

              // ── Tertiary: "Wrong email?" muted link, parked below buttons
              //    so it doesn't compete with the primary CTA for focus. ────
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isLoading ? null : _changeEmail,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    child: Text.rich(
                      TextSpan(
                        style: tt.bodySmall!.copyWith(color: c.text3),
                        children: [
                          const TextSpan(text: 'Wrong email? '),
                          TextSpan(
                            text: 'Change it',
                            style: tt.bodySmall!.copyWith(
                              color: c.text3,
                              decoration: TextDecoration.underline,
                              decorationColor: c.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Gap(AppSpacing.xl.h),
            ],
          ),
        ),
      ),
    );
  }
}
