import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';
import '../../../../core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/jobdun_logo.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
import '../../../../core/widgets/status_banner.dart';
import '../providers/auth_provider.dart';
import '../validators/password_rules.dart';

/// Where the password-reset link lands the user — the screen that was missing
/// entirely, and the reason resets never completed on either platform. The
/// recovery link only grants a session; something still has to write the new
/// password, which is this.
///
/// Reached only via the router's recovery gate (`AuthState.isPasswordRecovery`)
/// after gotrue exchanges the link's code and emits `passwordRecovery` — on
/// native through the `au.com.jobdun.app://login-callback/` deep link, on web
/// through `/auth/callback`. Same widget on both; nothing here is
/// platform-specific.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormBuilderState>();

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final password = _formKey.currentState!.value['password'] as String;
    // The router's gate releases as soon as isPasswordRecovery clears, so a
    // successful update navigates on its own — no explicit context.go here.
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .updatePassword(password);
    if (!ok || !mounted) return;
    // Confirm on the ScaffoldMessenger rather than this page's own banner:
    // the gate redirects to /home the instant the flag clears, so anything
    // rendered here is gone before it can be read. A messenger-owned SnackBar
    // survives the navigation and lands on the destination screen.
    messenger.showSnackBar(
      const SnackBar(content: Text('Password updated. You are signed in.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Gap(24.h),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    JobdunLogo(variant: LogoVariant.mark, height: 24.r),
                    Gap(8.w),
                    Text(
                      'JOBDUN',
                      style: tt.titleLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        height: 1.0,
                        color: c.text1,
                      ),
                    ),
                  ],
                ),
              ),

              Gap(32.h),

              Text(
                'SET A NEW\nPASSWORD.',
                style: tt.displayLarge!.copyWith(
                  letterSpacing: 0.8,
                  color: c.text1,
                  height: 1.05,
                ),
              ),
              Gap(10.h),
              Text(
                authState.email == null
                    ? 'Choose a new password for your account.'
                    : 'Choose a new password for ${authState.email}.',
                style: tt.bodyMedium!.copyWith(color: c.text2),
              ),

              Gap(AppSpacing.xl.h),

              FormBuilder(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    JTextField(
                      name: 'password',
                      label: 'New password',
                      hint: 'Min. 8 chars',
                      prefixIcon: AppIcons.lock,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(
                          errorText: 'Password is required.',
                        ),
                        FormBuilderValidators.minLength(
                          8,
                          errorText: 'At least 8 characters.',
                        ),
                        // Shared with sign-up so the two can't drift apart.
                        PasswordRules.strong,
                      ]),
                    ),
                    Gap(AppSpacing.sm.h),
                    JTextField(
                      name: 'confirmPassword',
                      label: 'Confirm new password',
                      hint: 'Re-enter your password',
                      prefixIcon: AppIcons.lock,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onSubmitted: (_) => _submit(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Confirm your password.';
                        }
                        // Read live rather than from the saved value — the
                        // confirm field validates before the form is saved.
                        final password =
                            _formKey.currentState?.fields['password']?.value
                                as String?;
                        return PasswordRules.confirmationError(password, value);
                      },
                    ),
                  ],
                ),
              ),

              Gap(8.h),

              if (authState.errorMessage != null) ...[
                StatusBanner(message: authState.errorMessage!, isError: true),
                Gap(8.h),
              ],

              Gap(AppSpacing.lg.h),

              JButton(
                label: authState.isLoading ? 'SAVING...' : 'SET NEW PASSWORD',
                isLoading: authState.isLoading,
                onPressed: authState.isLoading ? null : _submit,
              ),

              Gap(12.h),

              // Without this the gate is a trap: the recovery session keeps
              // the user "authenticated", so every route redirects back here.
              JButton(
                label: 'CANCEL',
                variant: JButtonVariant.secondary,
                onPressed: authState.isLoading
                    ? null
                    : () => ref
                          .read(authControllerProvider.notifier)
                          .cancelPasswordRecovery(),
              ),

              Gap(AppSpacing.xl.h),
            ],
          ),
        ),
      ),
    );
  }
}
