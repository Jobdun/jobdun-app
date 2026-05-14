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
import '../../../legal/presentation/widgets/legal_link_text.dart';
import '../providers/auth_provider.dart';
import '../widgets/social_auth_buttons.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;
    ref
        .read(authControllerProvider.notifier)
        .signIn(
          email: values['email'] as String,
          password: values['password'] as String,
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
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero — mark + gradient wordmark ──────────────────────────
                // Reduced ~30% (mark 64→44, wordmark 60→42, top gap 56→32) so
                // the full login screen fits a 360×640 viewport without
                // scrolling. New-user marketing now lives in the FTUE
                // carousel, freeing this surface for returning users only.
                Gap(32.h),
                Center(
                  child: SvgPicture.asset(
                    'lib/core/assets/mark-jobdun.svg',
                    width: 44.r,
                    height: 44.r,
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
                        Colors.white, // intentional: ShaderMask requires white
                      ).copyWith(fontSize: 42.sp),
                    ),
                  ),
                ),

                Gap(AppSpacing.xl.h),

                // ── Form ─────────────────────────────────────────────────────
                FormBuilder(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      JTextField(
                        name: 'email',
                        label: 'Email',
                        hint: 'your@email.com',
                        prefixIcon: Iconsax.sms,
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
                        prefixIcon: Iconsax.lock,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                        validator: FormBuilderValidators.required(
                          errorText: 'Password is required.',
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Status banners ────────────────────────────────────────────
                if (authState.errorMessage != null) ...[
                  Gap(AppSpacing.sm.h),
                  StatusBanner(message: authState.errorMessage!, isError: true),
                ],
                if (authState.infoMessage != null) ...[
                  Gap(AppSpacing.sm.h),
                  StatusBanner(message: authState.infoMessage!, isError: false),
                ],

                Gap(AppSpacing.lg.h),

                // ── Primary CTA ───────────────────────────────────────────────
                AppButton(
                  label: authState.isLoading ? 'LOGGING IN...' : 'LOG IN',
                  isLoading: authState.isLoading,
                  onPressed: authState.isLoading ? null : _submit,
                ),

                Gap(AppSpacing.md.h),

                // ── Forgot password (muted escape hatch — keeps orange c.action
                //    reserved for the LOG IN CTA only) ──────────────────────────
                Center(
                  child: Semantics(
                    button: true,
                    label: 'Forgot password? Tap to reset',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.go('/forgot-password'),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                        child: Text(
                          'Forgot password?',
                          style: tt.bodySmall!.copyWith(
                            color: c.text3,
                            decoration: TextDecoration.underline,
                            decorationColor: c.text3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Gap(AppSpacing.lg.h),

                // ── SSO — demoted to text link row ────────────────────────────
                const SocialAuthButtons(),

                Gap(AppSpacing.md.h),

                // ── Phone sign-in (alternative to email + SSO) ────────────────
                // Tradies on patchy work email or who never opened their Gmail
                // benefit from a phone-only path.
                Center(
                  child: Semantics(
                    button: true,
                    label: 'Sign in with your phone number',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.go('/phone-auth'),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: tt.bodySmall!.copyWith(color: c.text3),
                            children: [
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Icon(
                                  Iconsax.call,
                                  size: 14.r,
                                  color: c.text3,
                                ),
                              ),
                              const TextSpan(text: '  '),
                              TextSpan(
                                text: 'Use phone number',
                                style: tt.bodySmall!.copyWith(
                                  color: c.text3,
                                  decoration: TextDecoration.underline,
                                  decorationColor: c.text3,
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

                // ── Legal footer ──────────────────────────────────────────────
                const LegalLinkText(minimal: true),

                Gap(AppSpacing.xl.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
