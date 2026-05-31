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
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Role chip with CHANGE affordance ──────────────────────────────
          _RoleChip(role: role, onChange: onChangeRole, c: c, tt: tt),

          Gap(AppSpacing.md.h),

          Text(
            'CREATE ACCOUNT',
            style: tt.headlineMedium!.copyWith(
              color: c.text1,
              letterSpacing: 0.5,
            ),
          ),
          Gap(6.h),
          Text(headline, style: tt.bodyMedium!.copyWith(color: c.text2)),

          Gap(AppSpacing.lg.h),

          FormBuilder(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                JTextField(
                  name: 'full_name',
                  label: 'Full name',
                  hint: 'Your full name',
                  prefixIcon: AppIcons.user,
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
                JTextField(
                  name: 'email',
                  label: 'Email',
                  hint: 'your@email.com',
                  prefixIcon: AppIcons.email,
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
                JTextField(
                  name: 'password',
                  label: 'Password',
                  hint: 'Min. 8 chars',
                  prefixIcon: AppIcons.lock,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
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
                    _strongPasswordValidator,
                  ]),
                ),
                _PasswordStrengthBar(strength: strength, c: c, tt: tt),
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

          JButton(
            label: authState.isLoading
                ? 'CREATING ACCOUNT...'
                : 'CREATE ACCOUNT',
            isLoading: authState.isLoading,
            onPressed: onSubmit,
          ),

          Gap(AppSpacing.lg.h),

          Center(
            child: GestureDetector(
              onTap: onGoToLogin,
              child: RichText(
                text: TextSpan(
                  style: tt.bodySmall!.copyWith(color: c.text3),
                  children: [
                    const TextSpan(text: 'Already have an account? '),
                    TextSpan(
                      text: 'LOG IN',
                      style: tt.bodySmall!.copyWith(
                        color: c.actionInk,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
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

// ── Role chip ─────────────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.role,
    required this.onChange,
    required this.c,
    required this.tt,
  });

  final UserRole role;
  final VoidCallback onChange;
  final JColors c;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final isBuilder = role == UserRole.builder;
    final label = isBuilder ? 'HIRING' : 'LOOKING FOR WORK';
    final icon = isBuilder ? AppIcons.builder : AppIcons.briefcase;

    return Semantics(
      button: true,
      label: 'Currently signing up as $label. Tap to change.',
      child: GestureDetector(
        onTap: onChange,
        behavior: HitTestBehavior.opaque,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w,
              vertical: 8.h,
            ),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadius.btn.r),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: AppIconSize.micro.r, color: c.actionInk),
                Gap(8.w),
                Text(
                  label,
                  style: tt.labelSmall!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Gap(8.w),
                Container(width: 1, height: 12.h, color: c.border),
                Gap(8.w),
                Text(
                  'CHANGE',
                  style: tt.labelSmall!.copyWith(
                    color: c.actionInk,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Password strength ─────────────────────────────────────────────────────────

/// Composable validator block enforced on sign-up: ≥1 uppercase, ≥1 digit,
/// ≥1 symbol. Surfaces one rule at a time so the user gets actionable copy
/// instead of a "must contain X, Y, and Z" wall of text. The ≥8-char check
/// is the [FormBuilderValidators.minLength] entry one step up the chain.
String? _strongPasswordValidator(String? value) {
  if (value == null || value.isEmpty) return null; // .required handles this
  if (!RegExp(r'\d').hasMatch(value)) {
    return 'Include at least 1 number.';
  }
  if (!RegExp(r'[A-Z]').hasMatch(value)) {
    return 'Include at least 1 uppercase letter.';
  }
  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-=+]').hasMatch(value)) {
    return 'Include at least 1 symbol (! @ # \$ % etc.).';
  }
  return null;
}

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
        Text(
          label,
          style: tt.labelSmall!.copyWith(color: color, fontSize: 11.sp),
        ),
      ],
    );
  }
}
