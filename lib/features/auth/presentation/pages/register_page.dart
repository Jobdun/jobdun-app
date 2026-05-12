import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_gradients.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
import '../../../../core/widgets/status_banner.dart';
import '../../../legal/presentation/widgets/legal_acceptance_checkbox.dart';
import '../providers/auth_provider.dart';
import '../widgets/social_auth_buttons.dart';

// Total steps in the flow: role (1) + form (2) + verify email (3, separate page).
const _kTotalSteps = 3;

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  int _step = 1;
  UserRole? _selectedRole;
  bool _showRoleError = false;

  final _formKey = GlobalKey<FormBuilderState>();
  bool _ready = false;
  String _passwordValue = '';
  bool _termsAccepted = false;
  bool _showTermsError = false;

  @override
  void initState() {
    super.initState();
    // If the user came back via "Wrong email? Change it" on /verify-email, the
    // auth provider still has the draft. Jump straight to step 2 with role
    // + name + email pre-filled (FormBuilder uses each JTextField's initialValue).
    final draft = ref.read(authControllerProvider).registerDraft;
    if (draft != null) {
      _selectedRole = draft.role;
      _step = 2;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _advanceToForm() {
    if (_selectedRole == null) {
      setState(() => _showRoleError = true);
      return;
    }
    setState(() {
      _showRoleError = false;
      _step = 2;
    });
  }

  void _submit() {
    final formValid = _formKey.currentState?.saveAndValidate() ?? false;
    if (!_termsAccepted) {
      setState(() => _showTermsError = true);
    }
    if (!formValid || !_termsAccepted) return;
    final values = _formKey.currentState!.value;

    // Phone deferred: collected just-in-time when a Trade applies to a job
    // or a Builder posts their first job (T1.1 friction reduction sprint).
    // Marketing opt-in deferred: asked via day-3 in-app prompt — AU Spam Act
    // consent is more informed once the user has seen the product.
    ref
        .read(authControllerProvider.notifier)
        .register(
          email: values['email'] as String,
          password: values['password'] as String,
          fullName: values['full_name'] as String,
          role: _selectedRole,
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
        child: AnimatedOpacity(
          opacity: _ready ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Column(
            children: [
              // ── Top bar ───────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg.w,
                  vertical: 10.h,
                ),
                child: Row(
                  children: [
                    if (_step == 2)
                      IconButton(
                        onPressed: () => setState(() => _step = 1),
                        icon: Icon(
                          Iconsax.arrow_left,
                          color: c.text1,
                          size: 20.r,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: 40.r,
                          minHeight: 40.r,
                        ),
                      )
                    else
                      Gap(40.r),
                    const Spacer(),
                    Text(
                      '$_step / $_kTotalSteps',
                      style: tt.labelMedium!.copyWith(
                        color: c.text3,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Step progress bar ─────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
                child: _StepProgressBar(
                  currentStep: _step,
                  totalSteps: _kTotalSteps,
                  c: c,
                ),
              ),

              Gap(AppSpacing.lg.h),

              // ── Step content ──────────────────────────────────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: _step == 1
                      ? _RoleStep(
                          key: const ValueKey(1),
                          selectedRole: _selectedRole,
                          showError: _showRoleError,
                          onRoleChanged: (r) => setState(() {
                            _selectedRole = r;
                            _showRoleError = false;
                          }),
                          onContinue: _advanceToForm,
                          onGoToLogin: () => context.go('/login'),
                          c: c,
                          tt: tt,
                        )
                      : _FormStep(
                          key: const ValueKey(2),
                          formKey: _formKey,
                          authState: authState,
                          draft: authState.registerDraft,
                          passwordValue: _passwordValue,
                          termsAccepted: _termsAccepted,
                          showTermsError: _showTermsError,
                          onTermsChanged: (v) => setState(() {
                            _termsAccepted = v;
                            if (v) _showTermsError = false;
                          }),
                          onPasswordChanged: (v) =>
                              setState(() => _passwordValue = v ?? ''),
                          onSubmit: authState.isLoading ? null : _submit,
                          onGoToLogin: () => context.go('/login'),
                          c: c,
                          tt: tt,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step progress bar ─────────────────────────────────────────────────────────

class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({
    required this.currentStep,
    required this.totalSteps,
    required this.c,
  });

  final int currentStep;
  final int totalSteps;
  final JColors c;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (i) {
        final active = i < currentStep;
        return Expanded(
          child: Container(
            height: 3.h,
            margin: EdgeInsets.only(right: i < totalSteps - 1 ? 4.w : 0),
            decoration: BoxDecoration(
              color: active ? c.action : c.border,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
        );
      }),
    );
  }
}

// ── Step 1: Role selection ────────────────────────────────────────────────────

class _RoleStep extends StatelessWidget {
  const _RoleStep({
    super.key,
    required this.selectedRole,
    required this.showError,
    required this.onRoleChanged,
    required this.onContinue,
    required this.onGoToLogin,
    required this.c,
    required this.tt,
  });

  final UserRole? selectedRole;
  final bool showError;
  final ValueChanged<UserRole> onRoleChanged;
  final VoidCallback onContinue;
  final VoidCallback onGoToLogin;
  final JColors c;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Brand lockup (compact horizontal) ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'lib/core/assets/mark-jobdun.svg',
                width: 32.r,
                height: 32.r,
              ),
              Gap(10.w),
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppGradients.brandFlame.createShader(bounds),
                child: Text(
                  'JOBDUN',
                  style: AppTheme.brandDisplay(
                    Colors.white, // intentional: ShaderMask requires white
                  ).copyWith(fontSize: 32.sp),
                ),
              ),
            ],
          ),

          Gap(AppSpacing.xl.h),

          Text(
            'WHO ARE YOU?',
            style: tt.headlineMedium!.copyWith(
              color: c.text1,
              letterSpacing: 0.5,
            ),
          ),
          Gap(6.h),
          Text(
            'Select your role to get started.',
            style: tt.bodyMedium!.copyWith(color: c.text2),
          ),

          Gap(AppSpacing.lg.h),

          // ── Role cards ────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _RoleCard(
                  role: UserRole.builder,
                  icon: Iconsax.buildings,
                  label: 'BUILDER',
                  description: 'Post jobs, hire crews',
                  selected: selectedRole == UserRole.builder,
                  onTap: () => onRoleChanged(UserRole.builder),
                  c: c,
                  tt: tt,
                ),
              ),
              Gap(12.w),
              Expanded(
                child: _RoleCard(
                  role: UserRole.trade,
                  icon: Iconsax.cpu_charge,
                  label: 'TRADES',
                  description: 'Find work, get paid',
                  selected: selectedRole == UserRole.trade,
                  onTap: () => onRoleChanged(UserRole.trade),
                  c: c,
                  tt: tt,
                ),
              ),
            ],
          ),

          if (showError) ...[
            Gap(8.h),
            Text(
              'Select a role to continue.',
              style: tt.bodySmall!.copyWith(color: c.urgent, fontSize: 12.sp),
            ),
          ],

          Gap(AppSpacing.xl.h),

          AppButton(label: 'Continue', onPressed: onContinue),

          Gap(AppSpacing.lg.h),

          // ── SSO alternative ───────────────────────────────────────────────
          const SocialAuthButtons(),

          Gap(AppSpacing.lg.h),

          // ── Already have an account ────────────────────────────────────────
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
                        color: c.action,
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
    required this.c,
    required this.tt,
  });

  final UserRole role;
  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final JColors c;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(AppSpacing.md.r),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(
            color: selected ? c.action : c.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32.r, color: selected ? c.action : c.text3),
            Gap(AppSpacing.md.h),
            Text(
              label,
              style: tt.labelLarge!.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            Gap(4.h),
            Text(
              description,
              style: tt.bodySmall!.copyWith(color: c.text2, fontSize: 12.sp),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 2: Account form ──────────────────────────────────────────────────────

class _FormStep extends StatelessWidget {
  const _FormStep({
    super.key,
    required this.formKey,
    required this.authState,
    required this.draft,
    required this.passwordValue,
    required this.termsAccepted,
    required this.showTermsError,
    required this.onTermsChanged,
    required this.onPasswordChanged,
    required this.onSubmit,
    required this.onGoToLogin,
    required this.c,
    required this.tt,
  });

  final GlobalKey<FormBuilderState> formKey;
  final AuthState authState;
  final RegisterDraft? draft;
  final String passwordValue;
  final bool termsAccepted;
  final bool showTermsError;
  final ValueChanged<bool> onTermsChanged;
  final ValueChanged<String?> onPasswordChanged;
  final VoidCallback? onSubmit;
  final VoidCallback onGoToLogin;
  final JColors c;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final strength = _passwordStrength(passwordValue);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CREATE ACCOUNT',
            style: tt.headlineMedium!.copyWith(
              color: c.text1,
              letterSpacing: 0.5,
            ),
          ),
          Gap(4.h),
          Text(
            'Your details — we keep it tight.',
            style: tt.bodyMedium!.copyWith(color: c.text2),
          ),

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
                  prefixIcon: Iconsax.user,
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
                  prefixIcon: Iconsax.sms,
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
                  prefixIcon: Iconsax.lock,
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
                    (val) {
                      if (val != null && !RegExp(r'\d').hasMatch(val)) {
                        return 'Include at least 1 number.';
                      }
                      return null;
                    },
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

          AppButton(
            label: authState.isLoading
                ? 'Creating account...'
                : 'Create Account',
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
                        color: c.action,
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
        Text(
          label,
          style: tt.labelSmall!.copyWith(color: color, fontSize: 11.sp),
        ),
      ],
    );
  }
}
