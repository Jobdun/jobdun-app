import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/services/auth_analytics.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/jobdun_logo.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
import '../../../../core/widgets/status_banner.dart';
import '../../../legal/presentation/widgets/legal_link_text.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_header.dart';
import '../widgets/auth_sso_row.dart';
import '../widgets/browse_jobs_link.dart';

/// Sign-in screen, built on Figma `JobDun-Screens` → Login (node 63:1718).
///
/// Server-side auth failures land on the password field rather than in a
/// banner, matching the mock's "Wrong password *" caption — a red field the
/// user is already looking at beats a block of text above the fold. Errors
/// that are not about a field (network, rate limit, unconfirmed email) still
/// need somewhere to go, so [StatusBanner] is kept strictly for those; see
/// [_isCredentialError].
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormBuilderState>();
  // Owned focus nodes wire the email → password Next-key traversal
  // deterministically. Without them Flutter's auto-traversal usually works
  // inside a FormBuilder but isn't guaranteed across platform IMEs.
  final _emailFocus = FocusNode(debugLabel: 'login.email');
  final _passwordFocus = FocusNode(debugLabel: 'login.password');
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    AuthAnalytics.loginScreenViewed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // A banner earned on another auth screen must not re-render here.
      ref.read(authControllerProvider.notifier).clearMessages();
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// True when the server rejected the credentials themselves — the one class
  /// of error the mock renders inline under Password. Everything else
  /// (offline, rate-limited, email not confirmed) describes the request, not
  /// the field, and keeps the banner.
  static bool _isCredentialError(String? message) {
    if (message == null) return false;
    final m = message.toLowerCase();
    return m.contains('invalid login') ||
        m.contains('invalid credentials') ||
        m.contains('incorrect') ||
        m.contains('wrong password');
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
    // ?from=login flags the FTUE to show a back-arrow on slide 1 — the user
    // just came from here and must be able to get back.
    context.go('/ftue?from=login');
  }

  // Guest browsing (App Review 5.1.1(v)) — the public job browser must be
  // reachable from the auth wall without creating an account.
  void _onBrowseJobs() {
    context.go('/browse');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final authState = ref.watch(authControllerProvider);
    final isBusy = authState.isLoading;

    final credentialError = _isCredentialError(authState.errorMessage)
        ? authState.errorMessage
        : null;
    final bannerError = credentialError == null ? authState.errorMessage : null;

    return Scaffold(
      backgroundColor: c.background,
      // Tap-outside-to-dismiss — taps on the background between fields unfocus
      // the active editor so the keyboard retracts. behavior:opaque ensures the
      // gesture wins against InkWell ripples on SSO tiles.
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: AnimatedOpacity(
            opacity: _ready ? 1.0 : 0.0,
            duration: AppMotion.fast,
            child: Column(
              children: [
                AuthHeader(
                  title: 'Login',
                  // Only when there is something to pop. Reached from the FTUE
                  // via context.go the stack is empty, and a caret that pops
                  // nothing is worse than no caret.
                  onBack: context.canPop() ? context.pop : null,
                ),
                Expanded(
                  // LayoutBuilder + minHeight lets the column grow to fill a
                  // tall viewport (so the legal footer pins to the bottom) and
                  // fall back to natural scroll on short ones, so nothing
                  // clips on 360x640.
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.md.w,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Gap(AppSpacing.md.h),

                                // The mark alone, not the full lockup — the
                                // header already names the screen, so a
                                // wordmark here would say it twice.
                                Center(
                                  child: JobdunLogo(
                                    variant: LogoVariant.mark,
                                    height: 57.h,
                                  ),
                                ),

                                Gap(AppSpacing.lg.h),

                                // AutofillGroup binds email + password into one
                                // credential pair so iOS Keychain / Android
                                // Autofill can offer "Save password?" atomically
                                // after a successful first login.
                                AutofillGroup(
                                  child: FormBuilder(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        JTextField(
                                          name: 'email',
                                          label: 'Email',
                                          hint: 'Enter your email',
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          textInputAction: TextInputAction.next,
                                          autofillHints: const [
                                            AutofillHints.email,
                                          ],
                                          focusNode: _emailFocus,
                                          autocorrect: false,
                                          enableSuggestions: false,
                                          onSubmitted: (_) =>
                                              _passwordFocus.requestFocus(),
                                          validator:
                                              FormBuilderValidators.compose([
                                                FormBuilderValidators.required(
                                                  errorText:
                                                      'Email is required.',
                                                ),
                                                FormBuilderValidators.email(
                                                  errorText:
                                                      'Enter a valid email.',
                                                ),
                                              ]),
                                        ),
                                        Gap(AppSpacing.sm.h),
                                        JTextField(
                                          name: 'password',
                                          label: 'Password',
                                          hint: 'Enter your password',
                                          obscureText: true,
                                          textInputAction: TextInputAction.done,
                                          autofillHints: const [
                                            AutofillHints.password,
                                          ],
                                          focusNode: _passwordFocus,
                                          autocorrect: false,
                                          enableSuggestions: false,
                                          onSubmitted: (_) => _submit(),
                                          // Server rejection renders here, in
                                          // the field the user has to fix.
                                          forcedErrorText: credentialError,
                                          validator:
                                              FormBuilderValidators.required(
                                                errorText:
                                                    'Password is required.',
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                _ForgotPasswordLink(onTap: _onForgotPassword),

                                if (bannerError != null) ...[
                                  Gap(AppSpacing.sm.h),
                                  StatusBanner(
                                    message: bannerError,
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

                                Gap(AppSpacing.lg.h),

                                JButton(
                                  label: isBusy ? 'Logging in...' : 'Log in',
                                  isLoading: isBusy,
                                  onPressed: isBusy ? null : _submit,
                                ),

                                Gap(AppSpacing.lg.h),

                                AuthSsoRow(
                                  onGoogle: _onGoogle,
                                  onApple: _onApple,
                                  onPhone: _onPhone,
                                  isBusy: isBusy,
                                ),

                                Gap(AppSpacing.lg.h),

                                _CreateAccountInlineLink(
                                  key: const Key('login.create_account_link'),
                                  onTap: _onCreateAccount,
                                ),

                                Gap(AppSpacing.sm.h),

                                BrowseJobsLink(
                                  key: const Key('login.browse_jobs_link'),
                                  onTap: _onBrowseJobs,
                                ),

                                const Spacer(),
                                Gap(AppSpacing.lg.h),

                                const LegalLinkText(minimal: true),

                                Gap(AppSpacing.md.h),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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

/// Right-aligned under both fields, as drawn (node 63:1907).
///
/// The mock sets this in `#FC5101`, which is 3.32:1 on the light ground and
/// fails the 4.5:1 body-text floor. `c.actionInk` is the token that exists for
/// orange-as-text and clears it at 4.92:1.
class _ForgotPasswordLink extends StatelessWidget {
  const _ForgotPasswordLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: 'Forgot password. Reset it.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
          child: Text(
            'Forgot Password ?',
            textAlign: TextAlign.right,
            style: tt.bodyMedium!.copyWith(
              fontSize: 14,
              height: 1.0,
              fontWeight: FontWeight.w700,
              color: c.actionInk,
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateAccountInlineLink extends StatelessWidget {
  const _CreateAccountInlineLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: 'Create an account.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Text.rich(
            textAlign: TextAlign.center,
            TextSpan(
              style: tt.bodyMedium!.copyWith(color: c.text2),
              children: [
                const TextSpan(text: "Don't have an account? "),
                TextSpan(
                  text: 'Create account',
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
    );
  }
}
