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
import '../../../../core/services/auth_analytics.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
import '../../../../core/widgets/social_auth_button.dart';
import '../../../../core/widgets/status_banner.dart';
import '../../../legal/presentation/widgets/legal_acceptance_checkbox.dart';
import '../providers/auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key, this.initialRole});

  // When set (via /register?role=…), step 1 is skipped — the user already
  // chose on /login. The form shows a CHANGE chip so a misclick is fixable.
  final UserRole? initialRole;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  int _step = 1;
  UserRole? _selectedRole;

  final _formKey = GlobalKey<FormBuilderState>();
  bool _ready = false;
  String _passwordValue = '';
  bool _termsAccepted = false;
  bool _showTermsError = false;

  @override
  void initState() {
    super.initState();
    // Priority order for initial role:
    //   1. registerDraft.role — user bounced back from /verify-email
    //   2. widget.initialRole — entered via /register?role=…
    //   3. null — show step 1 picker
    final draft = ref.read(authControllerProvider).registerDraft;
    if (draft != null) {
      _selectedRole = draft.role;
      _step = 2;
    } else if (widget.initialRole != null) {
      _selectedRole = widget.initialRole;
      _step = 2;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _pickRole(UserRole role) {
    // Tap-to-advance: no Continue button. Card tap = step 1 done.
    setState(() {
      _selectedRole = role;
      _step = 2;
    });
  }

  void _goBackToPicker() {
    setState(() => _step = 1);
  }

  void _onGoogle() {
    AuthAnalytics.ssoTapped(provider: 'google');
    ref.read(authControllerProvider.notifier).signInWithGoogle();
  }

  void _onApple() {
    AuthAnalytics.ssoTapped(provider: 'apple');
    ref.read(authControllerProvider.notifier).signInWithApple();
  }

  void _onPhone() {
    AuthAnalytics.phoneTapped();
    context.push('/phone-auth');
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
              // ── Top bar — back arrow only when we have somewhere to go ────
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg.w,
                  vertical: 10.h,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_step == 2 && widget.initialRole == null) {
                          // User picked role inline — back returns to picker.
                          _goBackToPicker();
                        } else {
                          // Pre-picked from /login or already on step 1 —
                          // back exits the whole flow.
                          context.go('/login');
                        }
                      },
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
                    ),
                    const Spacer(),
                  ],
                ),
              ),

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
                          onRolePicked: _pickRole,
                          onGoToLogin: () => context.go('/login'),
                          onGoogle: _onGoogle,
                          onApple: _onApple,
                          onPhone: _onPhone,
                          isBusy: authState.isLoading,
                          c: c,
                          tt: tt,
                        )
                      : _FormStep(
                          key: const ValueKey(2),
                          role: _selectedRole!,
                          formKey: _formKey,
                          authState: authState,
                          draft: authState.registerDraft,
                          passwordValue: _passwordValue,
                          termsAccepted: _termsAccepted,
                          showTermsError: _showTermsError,
                          // CHANGE chip — let the user fix a misclick.
                          // When initialRole was supplied via deep-link, go
                          // back to the picker rather than just /login so
                          // they can flip role without losing the funnel.
                          onChangeRole: _goBackToPicker,
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

// ── Step 1: Role selection ────────────────────────────────────────────────────

class _RoleStep extends StatelessWidget {
  const _RoleStep({
    super.key,
    required this.selectedRole,
    required this.onRolePicked,
    required this.onGoToLogin,
    required this.onGoogle,
    required this.onApple,
    required this.onPhone,
    required this.isBusy,
    required this.c,
    required this.tt,
  });

  final UserRole? selectedRole;
  final ValueChanged<UserRole> onRolePicked;
  final VoidCallback onGoToLogin;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onPhone;
  final bool isBusy;
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
            'WHICH SIDE ARE YOU ON?',
            style: tt.headlineMedium!.copyWith(
              color: c.text1,
              letterSpacing: 0.5,
            ),
          ),
          Gap(6.h),
          Text(
            'Tap to continue — you can switch later.',
            style: tt.bodyMedium!.copyWith(color: c.text2),
          ),

          Gap(AppSpacing.lg.h),

          // ── Role cards — tap-to-advance ───────────────────────────────────
          _RoleCard(
            role: UserRole.builder,
            icon: Iconsax.buildings,
            label: "I'M HIRING",
            description: 'Post jobs. Review applicants. Manage crews.',
            selected: selectedRole == UserRole.builder,
            onTap: () => onRolePicked(UserRole.builder),
            c: c,
            tt: tt,
          ),
          Gap(12.h),
          _RoleCard(
            role: UserRole.trade,
            icon: Iconsax.briefcase,
            label: "I'M LOOKING FOR WORK",
            description: 'Browse jobs. Apply. Get hired.',
            selected: selectedRole == UserRole.trade,
            onTap: () => onRolePicked(UserRole.trade),
            c: c,
            tt: tt,
          ),

          Gap(AppSpacing.xl.h),

          // ── SSO alternative — matches /login icon-tile row ────────────────
          // Same Google · Apple · Phone trio as LoginPage so users land on a
          // single consistent SSO surface across both auth entry points.
          _OrDivider(c: c, tt: tt),
          Gap(AppSpacing.md.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SocialAuthButton.google(
                key: const Key('register.sso.google'),
                onTap: isBusy ? () {} : onGoogle,
                isLoading: isBusy,
              ),
              SocialAuthButton.apple(
                key: const Key('register.sso.apple'),
                onTap: isBusy ? () {} : onApple,
                isLoading: isBusy,
              ),
              SocialAuthButton.phone(
                key: const Key('register.sso.phone'),
                onTap: isBusy ? () {} : onPhone,
                isLoading: isBusy,
              ),
            ],
          ),

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
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(AppSpacing.lg.r),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            border: Border.all(
              color: selected ? c.action : c.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48.r,
                height: 48.r,
                decoration: BoxDecoration(
                  color: selected ? c.action : c.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppRadius.avatar.r),
                ),
                child: Icon(
                  icon,
                  size: 22.r,
                  color: selected
                      ? Colors
                            .white // intentional: white-on-action
                      : c.text2,
                ),
              ),
              Gap(AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      style: tt.bodySmall!.copyWith(
                        color: c.text2,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Gap(AppSpacing.sm.w),
              Icon(
                Iconsax.arrow_right_3,
                size: 18.r,
                color: selected ? c.action : c.text3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final icon = isBuilder ? Iconsax.buildings : Iconsax.briefcase;

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
                Icon(icon, size: 14.r, color: c.action),
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

// ── "── or ──" section divider ──────────────────────────────────────────────
// Mirrors the divider on /login above the SSO icon row so both auth pages
// share the same "email path above, social path below" rhythm.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.c, required this.tt});

  final JColors c;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Divider(color: c.border, thickness: 1, height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
          child: Text('or', style: tt.bodySmall!.copyWith(color: c.text3)),
        ),
        Expanded(child: Divider(color: c.border, thickness: 1, height: 1)),
      ],
    );
  }
}
