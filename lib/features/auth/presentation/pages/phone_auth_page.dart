import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:pinput/pinput.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/status_banner.dart';
import '../providers/auth_provider.dart';

class PhoneAuthPage extends ConsumerStatefulWidget {
  const PhoneAuthPage({super.key});

  @override
  ConsumerState<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends ConsumerState<PhoneAuthPage> {
  final _pageController = PageController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  int _step = 0; // 0 = phone entry, 1 = otp entry
  int _resendCountdown = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _pageController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) t.cancel();
      });
    });
  }

  Future<void> _submitPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    final ok = await ref
        .read(authControllerProvider.notifier)
        .signInWithPhone(phone);

    if (ok && mounted) {
      setState(() => _step = 1);
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startResendTimer();
    }
  }

  Future<void> _submitOtp(String token) async {
    if (token.length < 6) return;
    await ref.read(authControllerProvider.notifier).verifyPhoneOtp(token);
  }

  Future<void> _resend() async {
    if (_resendCountdown > 0) return;
    await ref.read(authControllerProvider.notifier).resendPhoneOtp();
    _startResendTimer();
  }

  void _backToPhone() {
    setState(() => _step = 0);
    _otpController.clear();
    ref.read(authControllerProvider.notifier).clearPendingPhone();
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        leading: _step == 0
            ? IconButton(
                icon: Icon(Iconsax.arrow_left, color: c.text1),
                onPressed: () => context.pop(),
              )
            : IconButton(
                icon: Icon(Iconsax.arrow_left, color: c.text1),
                onPressed: _backToPhone,
              ),
        elevation: 0,
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _PhoneStep(
              phoneController: _phoneController,
              authState: authState,
              onSubmit: _submitPhone,
              c: c,
              tt: tt,
            ),
            _OtpStep(
              otpController: _otpController,
              phone: _phoneController.text,
              authState: authState,
              resendCountdown: _resendCountdown,
              onOtpComplete: _submitOtp,
              onResend: _resend,
              c: c,
              tt: tt,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 1: Phone entry ──────────────────────────────────────────────────────

class _PhoneStep extends StatelessWidget {
  const _PhoneStep({
    required this.phoneController,
    required this.authState,
    required this.onSubmit,
    required this.c,
    required this.tt,
  });

  final TextEditingController phoneController;
  final AuthState authState;
  final VoidCallback onSubmit;
  final JColors c;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Gap(32.h),
          Center(
            child: SvgPicture.asset(
              'lib/core/assets/mark-jobdun.svg',
              width: 56.r,
              height: 56.r,
              colorFilter: ColorFilter.mode(c.action, BlendMode.srcIn),
            ),
          ),
          Gap(AppSpacing.md.h),
          Text(
            'PHONE SIGN IN',
            textAlign: TextAlign.center,
            style: tt.headlineMedium!.copyWith(fontSize: 26.sp, letterSpacing: 2),
          ),
          Gap(8.h),
          Text(
            'Enter your mobile number to receive a verification code.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium!.copyWith(color: c.text2),
          ),
          Gap(AppSpacing.xl.h),

          Text(
            'MOBILE NUMBER',
            style: tt.labelSmall!.copyWith(
              letterSpacing: 0.12 * 11,
              color: c.text2,
            ),
          ),
          Gap(6.h),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            style: tt.bodyLarge!.copyWith(color: c.text1, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: '+61 4xx xxx xxx',
              prefixIcon: Icon(Iconsax.call, size: 18.r),
              contentPadding: EdgeInsets.symmetric(
                vertical: AppSpacing.md.h,
                horizontal: AppSpacing.md.w,
              ),
            ),
          ),

          if (authState.errorMessage != null) ...[
            Gap(AppSpacing.md.h),
            StatusBanner(message: authState.errorMessage!, isError: true),
          ],
          if (authState.infoMessage != null) ...[
            Gap(AppSpacing.md.h),
            StatusBanner(message: authState.infoMessage!, isError: false),
          ],

          Gap(AppSpacing.xl.h),
          AppButton(
            label: authState.isLoading ? 'Sending code...' : 'SEND CODE',
            isLoading: authState.isLoading,
            onPressed: authState.isLoading ? null : onSubmit,
          ),
          Gap(AppSpacing.xl.h),
        ],
      ),
    );
  }
}

// ── Step 2: OTP entry ────────────────────────────────────────────────────────

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    required this.otpController,
    required this.phone,
    required this.authState,
    required this.resendCountdown,
    required this.onOtpComplete,
    required this.onResend,
    required this.c,
    required this.tt,
  });

  final TextEditingController otpController;
  final String phone;
  final AuthState authState;
  final int resendCountdown;
  final ValueChanged<String> onOtpComplete;
  final VoidCallback onResend;
  final JColors c;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final pinTheme = PinTheme(
      width: 48.w,
      height: 56.h,
      textStyle: tt.headlineSmall!.copyWith(color: c.text1, fontWeight: FontWeight.w700),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.input.r),
        border: Border.all(color: c.border),
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Gap(32.h),
          Center(
            child: Container(
              width: 64.r,
              height: 64.r,
              decoration: BoxDecoration(
                color: c.actionBg,
                borderRadius: BorderRadius.circular(AppRadius.card.r),
              ),
              child: Icon(Iconsax.message, size: 32.r, color: c.action),
            ),
          ),
          Gap(AppSpacing.md.h),
          Text(
            'ENTER CODE',
            textAlign: TextAlign.center,
            style: tt.headlineMedium!.copyWith(fontSize: 26.sp, letterSpacing: 2),
          ),
          Gap(8.h),
          Text(
            'We sent a 6-digit code to\n$phone',
            textAlign: TextAlign.center,
            style: tt.bodyMedium!.copyWith(color: c.text2),
          ),
          Gap(AppSpacing.xl.h),

          Center(
            child: Pinput(
              controller: otpController,
              length: 6,
              defaultPinTheme: pinTheme,
              focusedPinTheme: pinTheme.copyDecorationWith(
                border: Border.all(color: c.action, width: 2),
              ),
              onCompleted: onOtpComplete,
              autofocus: true,
            ),
          ),

          if (authState.errorMessage != null) ...[
            Gap(AppSpacing.md.h),
            StatusBanner(message: authState.errorMessage!, isError: true),
          ],
          if (authState.infoMessage != null) ...[
            Gap(AppSpacing.md.h),
            StatusBanner(message: authState.infoMessage!, isError: false),
          ],

          Gap(AppSpacing.xl.h),

          AppButton(
            label: authState.isLoading ? 'Verifying...' : 'VERIFY',
            isLoading: authState.isLoading,
            onPressed: authState.isLoading
                ? null
                : () => onOtpComplete(otpController.text),
          ),

          Gap(AppSpacing.md.h),

          Center(
            child: GestureDetector(
              onTap: resendCountdown > 0 ? null : onResend,
              child: Text(
                resendCountdown > 0
                    ? 'Resend in ${resendCountdown}s'
                    : 'Resend code',
                style: tt.bodyMedium!.copyWith(
                  color: resendCountdown > 0 ? c.text3 : c.action,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          Gap(AppSpacing.xl.h),
        ],
      ),
    );
  }
}
