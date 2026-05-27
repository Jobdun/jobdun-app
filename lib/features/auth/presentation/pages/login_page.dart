import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../app/theme/app_gradients.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/services/auth_analytics.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
import '../../../../core/widgets/social_auth_button.dart';
import '../../../../core/widgets/status_banner.dart';
import '../../../legal/presentation/widgets/legal_link_text.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormBuilderState>();
  // Remember-me checkbox was removed (T1.4): Supabase Auth already persists
  // sessions via flutter_secure_storage, and the checkbox was never wired up.
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    AuthAnalytics.loginScreenViewed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    AuthAnalytics.loginSubmitted();
    final values = _formKey.currentState!.value;
    ref
        .read(authControllerProvider.notifier)
        .signIn(
          email: values['email'] as String,
          password: values['password'] as String,
        );
  }

  void _onForgotPassword() {
    AuthAnalytics.forgotPasswordTapped();
    context.go('/forgot-password');
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

  void _onCreateAccount() {
    AuthAnalytics.createAccountLinkTapped();
    // ?from=login flags the FTUE to show a back-arrow on slide 1 and hide
    // the redundant "I already have an account · LOG IN" link on slide 3 —
    // the user just came from there.
    context.go('/ftue?from=login');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final authState = ref.watch(authControllerProvider);
    final isBusy = authState.isLoading;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: AnimatedOpacity(
          opacity: _ready ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          // LayoutBuilder + ConstrainedBox(minHeight) lets the inner Column
          // grow to fill the viewport on tall devices (so spaceBetween pins
          // the legal footer to the bottom edge) and gracefully falls back
          // to natural scroll on short ones (so nothing clips on 360×640).
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      // Top group flows from the top; the bottom group (create
                      // account + legal) is pushed to the viewport bottom by
                      // the Spacer in between.
                      children: [
                        // ── Hero — mark + gradient wordmark ──────────────────
                        // Sized per design-system/jobdun/pages/auth-onboarding
                        // ("Top 40% — Logo + bold identity statement"). 64px
                        // mark + 56sp wordmark land the hero at ~30% of a
                        // 640px viewport — dominant without pushing LOG IN
                        // out of the thumb zone on tall devices.
                        Gap(AppSpacing.lg.h),
                        Center(
                          child: SvgPicture.asset(
                            'lib/core/assets/mark-jobdun.svg',
                            width: 64.r,
                            height: 64.r,
                          ),
                        ),
                        Gap(AppSpacing.sm.h),
                        Center(
                          child: ShaderMask(
                            shaderCallback: (bounds) =>
                                AppGradients.brandFlame.createShader(bounds),
                            child: Text(
                              'JOBDUN',
                              style: AppTheme.brandDisplay(
                                Colors
                                    .white, // intentional: ShaderMask requires white
                              ).copyWith(fontSize: 56.sp),
                            ),
                          ),
                        ),

                        Gap(AppSpacing.xl.h),

                        // ── Icon row: Google · Apple · Phone ─────────────────
                        // Lifted above the email form per AUTH_FLOW_UNIFICATION_PLAN
                        // — SSO is the primary path for new users; email/password
                        // is the fallback below the divider. Same icon-tile shape
                        // (56x56) and brand colours retained to avoid disrupting
                        // the existing design language.
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            SocialAuthButton.google(
                              key: const Key('login.sso.google'),
                              onTap: isBusy ? () {} : _onGoogle,
                              isLoading: isBusy,
                            ),
                            SocialAuthButton.apple(
                              key: const Key('login.sso.apple'),
                              onTap: isBusy ? () {} : _onApple,
                              isLoading: isBusy,
                            ),
                            SocialAuthButton.phone(
                              key: const Key('login.sso.phone'),
                              onTap: isBusy ? () {} : _onPhone,
                              isLoading: isBusy,
                            ),
                          ],
                        ),

                        Gap(AppSpacing.lg.h),

                        // ── Section divider ──────────────────────────────────
                        _OrDivider(),

                        Gap(AppSpacing.md.h),

                        // ── Form ─────────────────────────────────────────────
                        FormBuilder(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              JTextField(
                                name: 'email',
                                label: 'Email',
                                hint: 'you@example.com',
                                prefixIcon: AppIcons.email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                validator: FormBuilderValidators.compose([
                                  FormBuilderValidators.required(
                                    errorText: 'Email is required.',
                                  ),
                                  FormBuilderValidators.email(
                                    errorText: 'Enter a valid email.',
                                  ),
                                ]),
                              ),
                              JTextField(
                                name: 'password',
                                label: 'Password',
                                hint: 'Enter your password',
                                prefixIcon: AppIcons.lock,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onSubmitted: (_) => _submit(),
                                validator: FormBuilderValidators.required(
                                  errorText: 'Password is required.',
                                ),
                                // Inline Forgot? link — industry-standard
                                // position; muted to keep c.action reserved
                                // for the LOG IN CTA only.
                                labelTrailing: _ForgotPasswordLink(
                                  onTap: _onForgotPassword,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Status banners ───────────────────────────────────
                        if (authState.errorMessage != null) ...[
                          Gap(AppSpacing.sm.h),
                          StatusBanner(
                            message: authState.errorMessage!,
                            isError: true,
                          ),
                        ],
                        if (authState.infoMessage != null) ...[
                          Gap(AppSpacing.sm.h),
                          StatusBanner(
                            message: authState.infoMessage!,
                            isError: false,
                          ),
                        ],

                        Gap(AppSpacing.md.h),

                        // ── Primary CTA ──────────────────────────────────────
                        JButton(
                          label: isBusy ? 'LOGGING IN...' : 'LOG IN',
                          isLoading: isBusy,
                          onPressed: isBusy ? null : _submit,
                        ),

                        // Flexible spacer pushes the bottom group (create-
                        // account + legal) to the viewport bottom on tall
                        // devices. Minimum gap ensures separation even on
                        // short screens where the spacer collapses.
                        const Spacer(),
                        Gap(AppSpacing.xxl.h),

                        // ── Create account (the friend-referral path) ────────
                        _CreateAccountLink(
                          key: const Key('login.create_account_link'),
                          onTap: _onCreateAccount,
                        ),

                        Gap(AppSpacing.xl.h),

                        // ── Legal footer ─────────────────────────────────────
                        // Applies to every auth path above (email login, SSO,
                        // phone, create account). Pinned to the viewport
                        // bottom by the Spacer above.
                        const LegalLinkText(minimal: true),

                        Gap(AppSpacing.lg.h),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Forgot-password inline link ─────────────────────────────────────────────
// Muted (text3) so the orange c.action stays reserved for the primary CTA.
// 48px hit area enforced via Padding inside a HitTestBehavior.opaque gesture.
//
// Note: lives inside JTextField's MergeSemantics. Wrapping this in an
// explicit Semantics(button: true, ...) conflicts with that merge during
// the framework's semantics flush — let GestureDetector's tap callback
// generate the tappable semantic node naturally.
class _ForgotPasswordLink extends StatelessWidget {
  const _ForgotPasswordLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
        child: Text(
          'Forgot?',
          style: tt.labelMedium!.copyWith(
            color: c.text3,
            decoration: TextDecoration.underline,
            decorationColor: c.text3,
          ),
        ),
      ),
    );
  }
}

// ── "── or ──" section divider ──────────────────────────────────────────────
class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

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

// ── Create account link ─────────────────────────────────────────────────────
// "Create account →" — the missing-link fix for users who landed on /login
// via friend referral / share with no existing account. Trimmed from the
// previous "New to Jobdun? Create account →" copy: the orange accent +
// arrow already mark this as the signup action; the prefix was filler
// (Hick's Law).
class _CreateAccountLink extends StatelessWidget {
  const _CreateAccountLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final linkStyle = tt.bodyMedium!.copyWith(
      color: c.action,
      fontWeight: FontWeight.w700,
    );

    return Semantics(
      button: true,
      label: 'Create an account.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: linkStyle,
              children: [
                const TextSpan(text: 'Create account'),
                const TextSpan(text: ' '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(
                    AppIcons.chevronRight,
                    size: 14.r,
                    color: c.action,
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
