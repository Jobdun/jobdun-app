import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/services/phone_auth_storage.dart';
import '../../../../core/validators/phone_validator.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/country_picker_sheet.dart';
import '../widgets/phone_auth_steps.dart';

// Two callers:
//   PhoneAuthMode.signIn      — public route /phone-auth, creates a session
//                               from a phone OTP (alternative to email auth)
//   PhoneAuthMode.addToAccount — gated route /profile/verify-phone, attaches
//                               a verified phone to the already-authed user
//                               so the T1 banner's phone slot can hit 100%.
//                               Short-circuits to a success state when the
//                               profile already has phone_verified_at set —
//                               re-entering the page after a prior verify
//                               would otherwise loop the user through fresh
//                               OTP attempts that surface as otp_expired.
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

  // addToAccount-only state: gates the initial render until we've checked
  // whether the profile already carries phone_verified_at.
  bool _checkingVerifiedStatus = false;
  bool _alreadyVerified = false;
  String? _verifiedPhone;

  // Briefly rendered after a successful verify so the user sees confirmation
  // before the page pops back to /profile/edit. Without this, the previous
  // implementation popped silently — easy to mistake for "nothing happened".
  bool _justVerified = false;

  // Local override for authState.errorMessage when the raw Supabase auth
  // error is jargon-y. Surfaced via _OtpStep.friendlyErrorMessage.
  String? _friendlyErrorOverride;

  @override
  void initState() {
    super.initState();
    if (widget.mode == PhoneAuthMode.signIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _restorePendingPhone();
      });
    } else {
      // addToAccount: check the live profile state before exposing the form
      // so a returning user doesn't get re-routed through OTP for a phone
      // that's already verified.
      _checkingVerifiedStatus = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _checkAlreadyVerified();
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

  Future<void> _checkAlreadyVerified() async {
    // Force a fresh read — the cached state may pre-date a verify that
    // happened in another session.
    await ref.read(profileControllerProvider.notifier).loadProfile();
    if (!mounted) return;
    final profile = ref.read(profileControllerProvider).profile;
    setState(() {
      _checkingVerifiedStatus = false;
      _alreadyVerified = profile?.isPhoneVerified ?? false;
      _verifiedPhone = profile?.phone;
    });
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
      setState(() {
        _step = 1;
        _submittedPhone = pending.e164;
        if (restoredCountry != null) _country = restoredCountry;
      });
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
      if (widget.mode == PhoneAuthMode.addToAccount && mounted) {
        await ref.read(profileControllerProvider.notifier).loadProfile();
        if (!mounted) return;
        // Surface a brief success state so the verify doesn't feel silent.
        // Then pop back to wherever the user came from (typically the
        // verification wizard or /profile/edit).
        setState(() => _justVerified = true);
        await Future.delayed(const Duration(milliseconds: 1400));
        if (mounted) context.pop();
      }
    } else if (mounted) {
      // Auth notifier sets errorMessage on failure. Map known jargon to a
      // friendlier line + auto-clear the OTP input so the user can retype
      // immediately without manually deleting the failed attempt.
      final raw = ref.read(authControllerProvider).errorMessage ?? '';
      setState(() {
        _friendlyErrorOverride = _friendlyOtpError(raw);
      });
      _otpController.clear();
    }
  }

  static String? _friendlyOtpError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('expired') ||
        lower.contains('invalid') ||
        lower.contains('otp_expired')) {
      return "That code didn't work or has expired. "
          'Tap Resend code to get a fresh one.';
    }
    if (lower.contains('rate') || lower.contains('too many')) {
      return 'Too many attempts — wait a minute, then resend.';
    }
    return raw.isEmpty ? null : raw;
  }

  Future<void> _resend() async {
    if (_resendCountdown > 0) return;
    setState(() {
      _friendlyErrorOverride = null;
    });
    _otpController.clear();
    await ref.read(authControllerProvider.notifier).resendPhoneOtp();
    _startResendTimer();
  }

  Future<void> _backToPhone() async {
    setState(() {
      _step = 0;
      _friendlyErrorOverride = null;
    });
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
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        leading: _step == 0 || _alreadyVerified || _justVerified
            ? IconButton(
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
                icon: Icon(AppIcons.back, color: c.text1),
                onPressed: _backToPhone,
              ),
        elevation: 0,
      ),
      body: SafeArea(child: _buildBody(authState)),
    );
  }

  Widget _buildBody(AuthState authState) {
    if (_checkingVerifiedStatus) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_alreadyVerified && widget.mode == PhoneAuthMode.addToAccount) {
      return _AlreadyVerifiedView(
        phone: _verifiedPhone,
        onDone: () => context.canPop() ? context.pop() : context.go('/profile'),
      );
    }
    if (_justVerified) return const _JustVerifiedOverlay();
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        PhoneAuthPhoneStep(
          phoneController: _phoneController,
          country: _country,
          onPickCountry: _pickCountry,
          authState: authState,
          onSubmit: _submitPhone,
          phoneError: _phoneError,
        ),
        PhoneAuthOtpStep(
          otpController: _otpController,
          phone: _submittedPhone,
          authState: authState,
          resendCountdown: _resendCountdown,
          onOtpComplete: _submitOtp,
          onResend: _resend,
          friendlyErrorMessage: _friendlyErrorOverride,
        ),
      ],
    );
  }
}

enum _RestoreChoice { continueIt, cancelAndStartOver }

/// Shown on `/profile/verify-phone` when the profile already carries a
/// non-null `phone_verified_at`. Replaces the previous behaviour where the
/// page would route the user back into a fresh OTP flow for a phone they
/// had already confirmed — that path surfaced `otp_expired` errors that
/// read like real failures.
class _AlreadyVerifiedView extends StatelessWidget {
  const _AlreadyVerifiedView({required this.phone, required this.onDone});

  final String? phone;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final masked = _mask(phone);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
      child: Column(
        children: [
          Gap(48.h),
          Container(
            width: 88.r,
            height: 88.r,
            decoration: BoxDecoration(
              color: c.verifiedBg,
              shape: BoxShape.circle,
            ),
            child: Icon(AppIcons.verified, size: 44.r, color: c.verified),
          ),
          Gap(AppSpacing.lg.h),
          Text(
            'PHONE VERIFIED',
            textAlign: TextAlign.center,
            style: tt.headlineMedium!.copyWith(
              fontSize: 24.sp,
              letterSpacing: 2,
              color: c.text1,
            ),
          ),
          Gap(8.h),
          Text(
            masked == null
                ? 'Your phone number is verified on this account.'
                : 'Verified on this account: $masked',
            textAlign: TextAlign.center,
            style: tt.bodyMedium!.copyWith(color: c.text2, height: 1.45),
          ),
          Gap(AppSpacing.md.h),
          Text(
            'To change your phone number, contact support — for now this is '
            'locked to the number you verified.',
            textAlign: TextAlign.center,
            style: tt.bodySmall!.copyWith(color: c.text3, height: 1.45),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: JButton(label: 'DONE', isLoading: false, onPressed: onDone),
          ),
          Gap(AppSpacing.xl.h),
        ],
      ),
    );
  }

  /// Masks all but the last 4 digits so the verified state can show the
  /// number for confirmation without leaking it in case of shoulder-surfing.
  static String? _mask(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.length <= 4) return digits;
    final visible = digits.substring(digits.length - 4);
    final hidden = '•' * (digits.length - 4);
    return '$hidden$visible';
  }
}

/// Rendered for ~1.4s after a successful OTP confirmation in
/// `addToAccount` mode, just before the page pops. The previous
/// implementation popped silently, which read as "nothing happened" when
/// the user expected confirmation.
class _JustVerifiedOverlay extends StatelessWidget {
  const _JustVerifiedOverlay();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96.r,
            height: 96.r,
            decoration: BoxDecoration(
              color: c.verifiedBg,
              shape: BoxShape.circle,
            ),
            child: Icon(AppIcons.verified, size: 48.r, color: c.verified),
          ),
          Gap(AppSpacing.lg.h),
          Text(
            'PHONE VERIFIED',
            textAlign: TextAlign.center,
            style: tt.headlineMedium!.copyWith(
              fontSize: 24.sp,
              letterSpacing: 2,
              color: c.text1,
            ),
          ),
          Gap(8.h),
          Text(
            'Taking you back…',
            style: tt.bodyMedium!.copyWith(color: c.text2),
          ),
        ],
      ),
    );
  }
}
