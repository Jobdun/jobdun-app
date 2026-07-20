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
import '../../../../core/services/auth_analytics.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/jobdun_logo.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
import '../../../../core/widgets/status_banner.dart';
import '../../../legal/presentation/widgets/legal_link_text.dart';
import '../providers/auth_provider.dart';
import '../widgets/browse_jobs_link.dart';

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
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
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

    return Scaffold(
      backgroundColor: c.background,
      // Tap-outside-to-dismiss — taps on the dark background between fields
      // unfocus the active editor so the keyboard retracts. behavior:opaque
      // ensures the gesture wins against InkWell ripples on SSO tiles.
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
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
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Fixed hero zone — gives the mark predictable
                          // breathing room (~22% of a 640dp viewport) so it
                          // brands the moment without competing with the form.
                          // Centering inside a fixed-height box lands the mark
                          // in the upper third regardless of viewport size,
                          // matching the "Top 40% — logo zone" rule in
                          // design-system/jobdun/pages/auth-onboarding.md.
                          SizedBox(
                            height: 140.h,
                            child: Center(
                              child: JobdunLogo(
                                variant: LogoVariant.full,
                                height: 72.h,
                              ),
                            ),
                          ),

                          Gap(AppSpacing.lg.h),

                          // AutofillGroup binds email + password into a single
                          // credential pair so iOS Keychain / Android Autofill
                          // can offer "Save password?" atomically after a
                          // successful first login.
                          AutofillGroup(
                            child: FormBuilder(
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
                                    focusNode: _emailFocus,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    keyboardAppearance: Brightness.dark,
                                    onSubmitted: (_) =>
                                        _passwordFocus.requestFocus(),
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
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    focusNode: _passwordFocus,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    keyboardAppearance: Brightness.dark,
                                    onSubmitted: (_) => _submit(),
                                    validator: FormBuilderValidators.required(
                                      errorText: 'Password is required.',
                                    ),
                                    labelTrailing: _ForgotPasswordLink(
                                      onTap: _onForgotPassword,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

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

                          Gap(AppSpacing.sm.h),

                          _CreateAccountInlineLink(
                            key: const Key('login.create_account_link'),
                            onTap: _onCreateAccount,
                          ),

                          Gap(AppSpacing.sm.h),

                          JButton(
                            label: isBusy ? 'LOGGING IN...' : 'LOG IN',
                            isLoading: isBusy,
                            onPressed: isBusy ? null : _submit,
                          ),

                          Gap(AppSpacing.lg.h),

                          _OrContinueWith(),

                          Gap(AppSpacing.md.h),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _BrandSsoTile(
                                key: const Key('login.sso.google'),
                                provider: _SsoProvider.google,
                                onTap: _onGoogle,
                                isLoading: isBusy,
                              ),
                              _BrandSsoTile(
                                key: const Key('login.sso.apple'),
                                provider: _SsoProvider.apple,
                                onTap: _onApple,
                                isLoading: isBusy,
                              ),
                              _BrandSsoTile(
                                key: const Key('login.sso.phone'),
                                provider: _SsoProvider.phone,
                                onTap: _onPhone,
                                isLoading: isBusy,
                              ),
                            ],
                          ),

                          Gap(AppSpacing.md.h),

                          BrowseJobsLink(
                            key: const Key('login.browse_jobs_link'),
                            onTap: _onBrowseJobs,
                          ),

                          const Spacer(),
                          Gap(AppSpacing.lg.h),

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
      ),
    );
  }
}

// Muted text3 so the orange c.action stays reserved for the primary CTA.
// Lives inside JTextField's MergeSemantics — an explicit Semantics wrapper
// conflicts with that merge, so the GestureDetector's tap callback generates
// the tappable semantic node naturally.
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
          'Forgot password?',
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

class _OrContinueWith extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Text(
        'or continue with',
        style: tt.bodySmall!.copyWith(color: c.text3),
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
    final base = tt.bodyMedium!.copyWith(color: c.text2);
    final link = tt.bodyMedium!.copyWith(
      color: c.actionInk,
      fontWeight: FontWeight.w700,
    );

    return Semantics(
      button: true,
      label: 'Create an account.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: base,
              children: [
                const TextSpan(text: "Don't have an account? "),
                TextSpan(text: 'Create account', style: link),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Brand-colored 56×56 SSO tile — Google (white), Apple (black), Phone (orange).
// Each provider gets its own colour block per the reference. 48dp minimum
// touch target is met (tile is 56dp). InkWell sits on top so the splash
// stays inside the rounded square. Loading state shows a centred spinner
// tinted for visibility against the brand background.
enum _SsoProvider { google, apple, phone }

class _BrandSsoTile extends StatelessWidget {
  const _BrandSsoTile({
    super.key,
    required this.provider,
    required this.onTap,
    required this.isLoading,
  });

  final _SsoProvider provider;
  final VoidCallback onTap;
  final bool isLoading;

  static const double _tileSize = 56;
  static const double _iconSize = 26;

  ({Color bg, Color fg, Color border, String label}) _spec(
    BuildContext context,
  ) {
    final c = context.c;
    return switch (provider) {
      _SsoProvider.google => (
        bg: Colors.white, // intentional: Google brand requires white tile
        fg: Colors.white, // intentional: unused; Google SVG is multi-colour
        border: c.border,
        label: 'Sign in with Google',
      ),
      _SsoProvider.apple => (
        bg: Colors.black, // intentional: Apple HIG monochrome on dark tile
        fg: Colors.white, // intentional: Apple HIG requires white mark on black
        border: Colors.black,
        label: 'Sign in with Apple',
      ),
      _SsoProvider.phone => (
        bg: c.action,
        fg: c.actionTx,
        border: c.action,
        label: 'Continue with phone number',
      ),
    };
  }

  Widget _icon(BuildContext context, Color fg) {
    return switch (provider) {
      _SsoProvider.google => SvgPicture.asset(
        'lib/core/assets/icon-google-color.svg',
        width: _iconSize.r,
        height: _iconSize.r,
      ),
      _SsoProvider.apple => SvgPicture.asset(
        'lib/core/assets/icon-apple.svg',
        width: _iconSize.r,
        height: _iconSize.r,
        colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
      ),
      _SsoProvider.phone => Icon(AppIcons.phone, size: _iconSize.r, color: fg),
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = _spec(context);
    final disabled = isLoading;

    return Semantics(
      button: true,
      label: s.label,
      excludeSemantics: true,
      child: Material(
        color: s.bg,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : onTap,
          child: Ink(
            width: _tileSize.r,
            height: _tileSize.r,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card.r),
              border: Border.all(color: s.border),
            ),
            child: Center(
              child: isLoading
                  ? SizedBox.square(
                      dimension: 18.r,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: s.fg,
                      ),
                    )
                  : _icon(context, s.fg),
            ),
          ),
        ),
      ),
    );
  }
}
