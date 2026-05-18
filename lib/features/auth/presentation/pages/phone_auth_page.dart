import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:pinput/pinput.dart';

import '../../../../app/constants/app_constants.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/jobdun_logo.dart';
import '../../../../core/services/phone_auth_storage.dart';
import '../../../../core/validators/phone_validator.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/status_banner.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/country_picker_sheet.dart';

// Two callers:
//   PhoneAuthMode.signIn      — public route /phone-auth, creates a session
//                               from a phone OTP (alternative to email auth)
//   PhoneAuthMode.addToAccount — gated route /profile/verify-phone, attaches
//                               a verified phone to the already-authed user
//                               so the T1 banner's phone slot can hit 100%.
enum PhoneAuthMode { signIn, addToAccount }

class PhoneAuthPage extends ConsumerStatefulWidget {
  const PhoneAuthPage({super.key, this.mode = PhoneAuthMode.signIn});

  final PhoneAuthMode mode;

  @override
  ConsumerState<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends ConsumerState<PhoneAuthPage> {
  final _pageController = PageController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  int _step = 0; // 0 = phone entry, 1 = OTP entry
  int _resendCountdown = 0;
  Timer? _resendTimer;
  String _submittedPhone = '';
  String? _phoneError;
  Country _country = defaultCountry();

  @override
  void initState() {
    super.initState();
    // The "continue with the in-flight OTP from last session" prompt only
    // makes sense for the sign-in flow. In add-to-account mode the user
    // is already authed and any persisted record predates them attaching
    // a phone — restore would just confuse.
    if (widget.mode == PhoneAuthMode.signIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _restorePendingPhone();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _restorePendingPhone() async {
    final pending = await PhoneAuthStorage.load();
    if (pending == null || !mounted) return;

    final restoredCountry = countryByCode(pending.countryCode);
    final choice = await showDialog<_RestoreChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final c = ctx.c;
        final tt = Theme.of(ctx).textTheme;
        return AlertDialog(
          backgroundColor: c.surface,
          title: Text(
            'Continue verification?',
            style: tt.titleMedium!.copyWith(color: c.text1),
          ),
          content: Text(
            'We sent a code to ${pending.e164} earlier. Want to continue with '
            'that number, or start over?',
            style: tt.bodyMedium!.copyWith(color: c.text2),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(_RestoreChoice.cancelAndStartOver),
              child: Text(
                'Start over',
                style: tt.bodyMedium!.copyWith(color: c.text3),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(_RestoreChoice.continueIt),
              child: Text(
                'Continue',
                style: tt.bodyMedium!.copyWith(
                  color: c.action,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (choice == _RestoreChoice.continueIt) {
      // Skip straight to the OTP step — the SMS was already sent.
      setState(() {
        _step = 1;
        _submittedPhone = pending.e164;
        if (restoredCountry != null) _country = restoredCountry;
      });
      // Sync the provider so verifyPhoneOtp knows which phone to verify against.
      ref.read(authControllerProvider.notifier).setPendingPhone(pending.e164);
      _pageController.jumpToPage(1);
      _startResendTimer();
    } else {
      await PhoneAuthStorage.clear();
    }
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) t.cancel();
      });
    });
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryPickerSheet(
      context,
      currentCode: _country.code,
    );
    if (picked != null && mounted) {
      setState(() {
        _country = picked;
        _phoneError = null;
      });
    }
  }

  Future<void> _submitPhone() async {
    final raw = _phoneController.text.trim();
    final error = _country.validate(raw);
    if (error != null) {
      setState(() => _phoneError = error);
      return;
    }
    setState(() => _phoneError = null);

    final e164 = _country.toE164(raw);
    final notifier = ref.read(authControllerProvider.notifier);
    final ok = widget.mode == PhoneAuthMode.signIn
        ? await notifier.signInWithPhone(e164)
        : await notifier.sendPhoneVerification(e164);

    if (ok && mounted) {
      // Only persist for sign-in — add-to-account resume after kill is a
      // weaker UX win (user is already authed; they can just re-tap).
      if (widget.mode == PhoneAuthMode.signIn) {
        await PhoneAuthStorage.save(
          e164Phone: e164,
          countryCode: _country.code,
        );
      }
      setState(() {
        _step = 1;
        _submittedPhone = e164;
      });
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
    final notifier = ref.read(authControllerProvider.notifier);
    final ok = widget.mode == PhoneAuthMode.signIn
        ? await notifier.verifyPhoneOtp(token)
        : await notifier.confirmPhoneVerification(token);
    if (ok) {
      await PhoneAuthStorage.clear();
      // In add-to-account mode we don't navigate — the user came from
      // /profile/edit and the trigger has now flipped phone_verified_at,
      // so we just pop back. Reload profile so the new state is visible.
      if (widget.mode == PhoneAuthMode.addToAccount && mounted) {
        await ref.read(profileControllerProvider.notifier).loadProfile();
        if (mounted) context.pop();
      }
    }
  }

  Future<void> _resend() async {
    if (_resendCountdown > 0) return;
    await ref.read(authControllerProvider.notifier).resendPhoneOtp();
    _startResendTimer();
  }

  Future<void> _backToPhone() async {
    setState(() => _step = 0);
    _otpController.clear();
    ref.read(authControllerProvider.notifier).clearPendingPhone();
    await PhoneAuthStorage.clear();
    if (!mounted) return;
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
                tooltip: 'Back',
                icon: Icon(AppIcons.back, color: c.text1),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/login');
                  }
                },
              )
            : IconButton(
                tooltip: 'Back',
                icon: Icon(AppIcons.back, color: c.text1),
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
              country: _country,
              onPickCountry: _pickCountry,
              authState: authState,
              onSubmit: _submitPhone,
              phoneError: _phoneError,
              c: c,
              tt: tt,
            ),
            _OtpStep(
              otpController: _otpController,
              phone: _submittedPhone,
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

enum _RestoreChoice { continueIt, cancelAndStartOver }

// ── Step 0: Phone entry ──────────────────────────────────────────────────────

class _PhoneStep extends StatelessWidget {
  const _PhoneStep({
    required this.phoneController,
    required this.country,
    required this.onPickCountry,
    required this.authState,
    required this.onSubmit,
    required this.phoneError,
    required this.c,
    required this.tt,
  });

  final TextEditingController phoneController;
  final Country country;
  final VoidCallback onPickCountry;
  final AuthState authState;
  final VoidCallback onSubmit;
  final String? phoneError;
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
            child: JobdunLogo(variant: LogoVariant.mark, height: 56.r),
          ),
          Gap(AppSpacing.md.h),
          Text(
            'PHONE SIGN IN',
            textAlign: TextAlign.center,
            style: tt.headlineMedium!.copyWith(
              fontSize: 26.sp,
              letterSpacing: 2,
            ),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Country selector — tap to open picker.
              InkWell(
                onTap: onPickCountry,
                borderRadius: BorderRadius.circular(AppRadius.input.r),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 13.h,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppRadius.input.r),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: [
                      Text(country.flag, style: TextStyle(fontSize: 20.sp)),
                      Gap(8.w),
                      Text(
                        '+${country.dialCode}',
                        style: tt.bodyLarge!.copyWith(
                          color: c.text1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Gap(4.w),
                      Icon(
                        AppIcons.expand,
                        size: AppIconSize.xs.r,
                        color: c.text3,
                      ),
                    ],
                  ),
                ),
              ),
              Gap(8.w),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppRadius.input.r),
                    border: Border.all(color: c.border),
                  ),
                  child: TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onSubmit(),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d\s]')),
                    ],
                    style: tt.bodyLarge!.copyWith(
                      color: c.text1,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: country.localFormatHint,
                      hintStyle: tt.bodyLarge!.copyWith(color: c.text3),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 13.h,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (phoneError != null) ...[
            Gap(AppSpacing.md.h),
            StatusBanner(message: phoneError!, isError: true),
          ],
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

// ── Step 1: OTP entry ────────────────────────────────────────────────────────

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
    final isLoading = authState.isLoading;

    final pinTheme = PinTheme(
      width: 48.w,
      height: 56.h,
      textStyle: tt.headlineSmall!.copyWith(
        color: c.text1,
        fontWeight: FontWeight.w700,
      ),
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
              child: Icon(
                AppIcons.messages.outline,
                size: AppIconSize.xl.r,
                color: c.action,
              ),
            ),
          ),
          Gap(AppSpacing.md.h),
          Text(
            'ENTER CODE',
            textAlign: TextAlign.center,
            style: tt.headlineMedium!.copyWith(
              fontSize: 26.sp,
              letterSpacing: 2,
            ),
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
              enabled: !isLoading,
              defaultPinTheme: pinTheme,
              focusedPinTheme: pinTheme.copyDecorationWith(
                border: Border.all(color: c.action, width: 2),
              ),
              onCompleted: isLoading ? null : onOtpComplete,
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

          ValueListenableBuilder<TextEditingValue>(
            valueListenable: otpController,
            builder: (context, value, _) {
              final isComplete = value.text.length == 6;
              return AppButton(
                label: isLoading ? 'Verifying...' : 'VERIFY',
                isLoading: isLoading,
                onPressed: (isLoading || !isComplete)
                    ? null
                    : () => onOtpComplete(otpController.text),
              );
            },
          ),

          Gap(AppSpacing.md.h),

          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 24.w),
              child: GestureDetector(
                onTap: (resendCountdown > 0 || isLoading) ? null : onResend,
                child: Opacity(
                  opacity: (resendCountdown > 0 || isLoading) ? 0.4 : 1.0,
                  child: Text(
                    resendCountdown > 0
                        ? 'Resend in ${resendCountdown}s'
                        : 'Resend code',
                    style: tt.bodyMedium!.copyWith(
                      color: c.action,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
