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
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/status_banner.dart';
import '../providers/auth_provider.dart';
import '../widgets/social_auth_buttons.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _obscurePassword = true;
  bool _rememberMe = false;
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
    ref.read(authControllerProvider.notifier).signIn(
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
                // ── Hero ─────────────────────────────────────────────────────
                Gap(48.h),
                Center(
                  child: SvgPicture.asset(
                    'lib/core/assets/mark-jobdun.svg',
                    width: 64.r,
                    height: 64.r,
                    colorFilter: ColorFilter.mode(c.action, BlendMode.srcIn),
                  ),
                ),
                Gap(AppSpacing.md.h),
                Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) =>
                        AppGradients.brandFlame.createShader(bounds),
                    child: Text(
                      'JOBDUN',
                      style: tt.displaySmall!.copyWith(
                        fontSize: 60.sp,
                        letterSpacing: 4.0,
                        height: 1.0,
                        color: Colors.white, // intentional: ShaderMask requires white for gradient
                      ),
                    ),
                  ),
                ),
                Gap(6.h),
                Center(
                  child: Text(
                    'Sign in to your account',
                    style: tt.bodyMedium!.copyWith(
                      color: c.text2,
                      fontSize: 14.sp,
                    ),
                  ),
                ),

                Gap(40.h),

                // ── Form ─────────────────────────────────────────────────────
                FormBuilder(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel(label: 'EMAIL', c: c),
                      Gap(6.h),
                      FormBuilderTextField(
                        name: 'email',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: tt.bodyLarge!.copyWith(
                          color: c.text1,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter your email',
                          prefixIcon: Icon(Iconsax.sms, size: 18.r),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: AppSpacing.md.h,
                            horizontal: AppSpacing.md.w,
                          ),
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.email(),
                        ]),
                      ),
                      Gap(18.h),
                      _FieldLabel(label: 'PASSWORD', c: c),
                      Gap(6.h),
                      FormBuilderTextField(
                        name: 'password',
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        style: tt.bodyLarge!.copyWith(
                          color: c.text1,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter your password',
                          prefixIcon: Icon(Iconsax.lock, size: 18.r),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: AppSpacing.md.h,
                            horizontal: AppSpacing.md.w,
                          ),
                          suffixIcon: GestureDetector(
                            onTap: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            child: Icon(
                              _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
                              size: 18.r,
                            ),
                          ),
                        ),
                        validator: FormBuilderValidators.required(),
                      ),
                      Gap(10.h),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                setState(() => _rememberMe = !_rememberMe),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 18.r,
                                  height: 18.r,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (v) => setState(
                                      () => _rememberMe = v ?? false,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                Gap(6.w),
                                Text(
                                  'REMEMBER ME',
                                  style: tt.labelSmall!.copyWith(
                                    letterSpacing: 0.5,
                                    color: c.text3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => context.go('/forgot-password'),
                            child: Text(
                              'FORGOT PASSWORD',
                              style: tt.labelSmall!.copyWith(
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w700,
                                color: c.action,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Gap(8.h),

                // ── Status banners ────────────────────────────────────────────
                if (authState.errorMessage != null) ...[
                  StatusBanner(message: authState.errorMessage!, isError: true),
                  Gap(8.h),
                ],
                if (authState.infoMessage != null) ...[
                  StatusBanner(message: authState.infoMessage!, isError: false),
                  Gap(8.h),
                ],

                Gap(AppSpacing.lg.h),

                // ── Primary CTA ───────────────────────────────────────────────
                AppButton(
                  label: authState.isLoading ? 'Logging in...' : 'Log in',
                  isLoading: authState.isLoading,
                  onPressed: authState.isLoading ? null : _submit,
                ),

                Gap(12.h),

                // ── OR divider ────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(child: Divider(color: c.border)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      child: Text(
                        'OR',
                        style: tt.labelSmall!.copyWith(
                          letterSpacing: 1.0,
                          color: c.text3,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: c.border)),
                  ],
                ),

                Gap(12.h),

                AppButton(
                  label: 'Sign Up',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.go('/register'),
                ),

                Gap(AppSpacing.lg.h),

                // ── Social SSO ────────────────────────────────────────────────
                const SocialAuthButtons(),

                Gap(AppSpacing.xl.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.c});

  final String label;
  final JColors c;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
        letterSpacing: 0.12 * 11,
        color: c.text2,
      ),
    );
  }
}
