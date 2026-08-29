part of 'register_page.dart';

// Step 2 (account form) widgets + password-strength helpers for the register
// flow, split into a `part` so `register_page.dart` stays under the file-size
// budget. Private, single-use, co-located with the page state. No behaviour
// change.

// ── Step 2: Account form ──────────────────────────────────────────────────────

class _FormStep extends StatelessWidget {
  const _FormStep({
    super.key,
    required this.role,
    required this.formKey,
    required this.authState,
    required this.draft,
    required this.passwordValue,
    required this.termsAccepted,
    required this.showTermsError,
    required this.onChangeRole,
    required this.onTermsChanged,
    required this.onPasswordChanged,
    required this.onSubmit,
    required this.onGoToLogin,
    required this.onGoogle,
    required this.onApple,
    required this.onPhone,
    required this.c,
    required this.tt,
  });

  final UserRole role;
  final GlobalKey<FormBuilderState> formKey;
  final AuthState authState;
  final RegisterDraft? draft;
  final String passwordValue;
  final bool termsAccepted;
  final bool showTermsError;
  final VoidCallback onChangeRole;
  final ValueChanged<bool> onTermsChanged;
  final ValueChanged<String?> onPasswordChanged;
  final VoidCallback? onSubmit;
  final VoidCallback onGoToLogin;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onPhone;
  final JColors c;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final strength = _passwordStrength(passwordValue);
    final isBuilder = role == UserRole.builder;
    final headline = isBuilder
        ? "Let's get your jobs in front of the right crews."
        : "Let's get you on the tools.";

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Gap(AppSpacing.sm.h),

          // The header names the screen and the role; this line is the only
          // remaining copy, so it says something the title cannot.
          Text(headline, style: tt.bodyMedium!.copyWith(color: c.text2)),

          Gap(AppSpacing.md.h),

          // Role changed its affordance: the CHANGE chip is gone because the
          // header now states the role, so the escape hatch is the back caret
          // that is already there. One route back, not two.
          FormBuilder(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                JTextField(
                  name: 'full_name',
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  initialValue: draft?.fullName,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(
                      errorText: 'Full name is required.',
                    ),
                    FormBuilderValidators.minLength(
                      2,
                      errorText: 'Name too short.',
                    ),
                  ]),
                ),
                Gap(AppSpacing.sm.h),
                JTextField(
                  name: 'email',
                  label: 'Email',
                  hint: 'your@email.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  initialValue: draft?.email,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(
                      errorText: 'Email is required.',
                    ),
                    FormBuilderValidators.email(
                      errorText: 'Enter a valid email.',
                    ),
                  ]),
                ),
                // Phone deferred to first job-apply (Trade) or first job-post
                // (Builder) — see _submit() for rationale.
                Gap(AppSpacing.sm.h),
                JTextField(
                  name: 'password',
                  label: 'Password',
                  hint: 'Enter a password',
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: onPasswordChanged,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(
                      errorText: 'Password is required.',
                    ),
                    FormBuilderValidators.minLength(
                      8,
                      errorText: 'At least 8 characters.',
                    ),
                    PasswordRules.strong,
                  ]),
                ),
                // Nothing typed yet is not "Weak" — an empty field has not
                // been judged, and opening the form on a red bar reads as a
                // failure the user has not had a chance to cause.
                if (passwordValue.isNotEmpty)
                  _PasswordStrengthBar(strength: strength, c: c, tt: tt),
                Gap(AppSpacing.sm.h),
                // Added by the mock (node 83:4771). A mistyped password on a
                // signup form is invisible until the user is locked out of the
                // account they just made, which is the worst possible moment
                // to find out.
                JTextField(
                  name: 'confirm_password',
                  label: 'Confirm Password',
                  hint: 'Confirm password',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  helperText: 'Must be minimum of 8 characters*',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirm your password.';
                    }
                    if (value != passwordValue) {
                      return 'Passwords do not match.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),

          Gap(14.h),

          // ── Terms acceptance — required under AU law.
          // Marketing opt-in deferred to day-3 in-app prompt (T1.1). Shared
          // widget keeps Terms/Privacy link copy in sync with login footer.
          LegalAcceptanceCheckbox(
            value: termsAccepted,
            onChanged: onTermsChanged,
            errorText: showTermsError && !termsAccepted
                ? 'Accept the terms to continue.'
                : null,
          ),

          // ── Status banners ────────────────────────────────────────────────
          if (authState.errorMessage != null) ...[
            Gap(AppSpacing.sm.h),
            StatusBanner(message: authState.errorMessage!, isError: true),
          ],
          if (authState.infoMessage != null) ...[
            Gap(AppSpacing.sm.h),
            StatusBanner(message: authState.infoMessage!, isError: false),
          ],

          Gap(AppSpacing.md.h),

          // Disabled until the terms are ticked, as drawn (node 36:8844). The
          // grey state is doing real work here: it says "one thing left"
          // rather than failing after the tap, which is what the old
          // always-enabled button did.
          JButton(
            label: authState.isLoading
                ? 'Creating account...'
                : 'Create Account',
            isLoading: authState.isLoading,
            onPressed: termsAccepted ? onSubmit : null,
          ),

          Gap(AppSpacing.lg.h),

          AuthSsoRow(
            keyPrefix: 'register',
            onGoogle: onGoogle,
            onApple: onApple,
            onPhone: onPhone,
            isBusy: authState.isLoading,
          ),

          Gap(AppSpacing.lg.h),

          Center(
            child: Semantics(
              button: true,
              label: 'Already have an account. Log in.',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onGoToLogin,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
                  child: Text.rich(
                    TextSpan(
                      style: tt.bodyMedium!.copyWith(color: c.text2),
                      children: [
                        const TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Log in',
                          style: tt.bodyMedium!.copyWith(
                            color: c.actionInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          Gap(AppSpacing.lg.h),
        ],
      ),
    );
  }
}

// ── Password strength ─────────────────────────────────────────────────────────

enum _PwStrength { weak, medium, strong }

_PwStrength _passwordStrength(String pw) {
  if (pw.length < 8) return _PwStrength.weak;
  final hasNumber = RegExp(r'\d').hasMatch(pw);
  final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>_\-=+]').hasMatch(pw);
  if (hasNumber && hasSpecial && pw.length >= 10) return _PwStrength.strong;
  if (hasNumber || hasSpecial) return _PwStrength.medium;
  return _PwStrength.weak;
}

class _PasswordStrengthBar extends StatelessWidget {
  const _PasswordStrengthBar({
    required this.strength,
    required this.c,
    required this.tt,
  });

  final _PwStrength strength;
  final JColors c;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (strength) {
      _PwStrength.weak => (c.urgent, 'Weak'),
      _PwStrength.medium => (c.star, 'Medium'),
      _PwStrength.strong => (c.verified, 'Strong'),
    };
    final filledSegments = switch (strength) {
      _PwStrength.weak => 1,
      _PwStrength.medium => 2,
      _PwStrength.strong => 3,
    };

    return Row(
      children: [
        ...List.generate(3, (i) {
          final filled = i < filledSegments;
          return Expanded(
            child: Container(
              height: 3.h,
              margin: EdgeInsets.only(right: i < 2 ? 4.w : 0),
              decoration: BoxDecoration(
                color: filled ? color : c.border,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          );
        }),
        Gap(8.w),
        Text(label, style: tt.labelSmall!.copyWith(color: color)),
      ],
    );
  }
}
