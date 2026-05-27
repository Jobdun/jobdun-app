import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/jobdun_logo.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/validators/phone_validator.dart';
import '../../../../core/widgets/status_banner.dart';
import '../providers/auth_provider.dart';

/// Phone entry + OTP entry step widgets for [PhoneAuthPage]. Lifted into a
/// sibling file so the parent stays under the LOC budget when the
/// already-verified short-circuit + success overlay landed.

class PhoneAuthPhoneStep extends StatelessWidget {
  const PhoneAuthPhoneStep({
    super.key,
    required this.phoneController,
    required this.country,
    required this.onPickCountry,
    required this.authState,
    required this.onSubmit,
    required this.phoneError,
  });

  final TextEditingController phoneController;
  final Country country;
  final VoidCallback onPickCountry;
  final AuthState authState;
  final VoidCallback onSubmit;
  final String? phoneError;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
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
                      Icon(AppIcons.chevronDown, size: 14.r, color: c.text3),
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
          JButton(
            label: authState.isLoading ? 'SENDING CODE...' : 'SEND CODE',
            isLoading: authState.isLoading,
            onPressed: authState.isLoading ? null : onSubmit,
          ),
          Gap(AppSpacing.xl.h),
        ],
      ),
    );
  }
}

class PhoneAuthOtpStep extends StatelessWidget {
  const PhoneAuthOtpStep({
    super.key,
    required this.otpController,
    required this.phone,
    required this.authState,
    required this.resendCountdown,
    required this.onOtpComplete,
    required this.onResend,
    required this.friendlyErrorMessage,
  });

  final TextEditingController otpController;
  final String phone;
  final AuthState authState;
  final int resendCountdown;
  final ValueChanged<String> onOtpComplete;
  final VoidCallback onResend;

  /// Override for `authState.errorMessage` when the parent maps a raw auth
  /// error (e.g. `Token has expired or is invalid`) to a friendlier line.
  /// When set, takes precedence over `authState.errorMessage`.
  final String? friendlyErrorMessage;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final isLoading = authState.isLoading;
    final errorMessage = friendlyErrorMessage ?? authState.errorMessage;

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
              child: Icon(AppIcons.chat, size: 32.r, color: c.action),
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
          if (errorMessage != null) ...[
            Gap(AppSpacing.md.h),
            StatusBanner(message: errorMessage, isError: true),
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
              return JButton(
                label: isLoading ? 'VERIFYING...' : 'VERIFY',
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
