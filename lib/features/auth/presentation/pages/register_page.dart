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

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
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
    ref.read(authControllerProvider.notifier).register(
      email: values['email'] as String,
      password: values['password'] as String,
      fullName: values['full_name'] as String,
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
                // ── Compact hero ──────────────────────────────────────────────
                Gap(24.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'lib/core/assets/mark-jobdun.svg',
                      width: 32.r,
                      height: 32.r,
                      colorFilter: ColorFilter.mode(c.action, BlendMode.srcIn),
                    ),
                    Gap(10.w),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppGradients.brandFlame.createShader(bounds),
                      child: Text(
                        'JOBDUN',
                        style: tt.headlineSmall!.copyWith(
                          fontSize: 36.sp,
                          letterSpacing: 3.0,
                          height: 1.0,
                          color: Colors.white, // intentional: ShaderMask requires white for gradient
                        ),
                      ),
                    ),
                  ],
                ),
                Gap(4.h),
                Center(
                  child: Text(
                    'Create your account',
                    style: tt.bodyMedium!.copyWith(color: c.text2),
                  ),
                ),

                Gap(20.h),

                // ── Form ─────────────────────────────────────────────────────
                FormBuilder(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel(label: 'FULL NAME', c: c),
                      Gap(4.h),
                      FormBuilderTextField(
                        name: 'full_name',
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        style: tt.bodyLarge!.copyWith(
                          color: c.text1,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Your full name',
                          prefixIcon: Icon(Iconsax.user, size: 16.r),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 12.h, horizontal: 14.w,
                          ),
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.minLength(2),
                        ]),
                      ),
                      Gap(12.h),
                      _FieldLabel(label: 'EMAIL', c: c),
                      Gap(4.h),
                      FormBuilderTextField(
                        name: 'email',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: tt.bodyLarge!.copyWith(
                          color: c.text1,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'your@email.com',
                          prefixIcon: Icon(Iconsax.sms, size: 16.r),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 12.h, horizontal: 14.w,
                          ),
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.email(),
                        ]),
                      ),
                      Gap(12.h),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel(label: 'PASSWORD', c: c),
                                Gap(4.h),
                                FormBuilderTextField(
                                  name: 'password',
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.next,
                                  style: tt.bodyLarge!.copyWith(
                                    color: c.text1,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Min. 8 chars',
                                    prefixIcon: Icon(Iconsax.lock, size: 16.r),
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 12.h, horizontal: 14.w,
                                    ),
                                    suffixIcon: GestureDetector(
                                      onTap: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                      child: Icon(
                                        _obscurePassword
                                            ? Iconsax.eye_slash
                                            : Iconsax.eye,
                                        size: 16.r,
                                      ),
                                    ),
                                  ),
                                  validator: FormBuilderValidators.compose([
                                    FormBuilderValidators.required(),
                                    FormBuilderValidators.minLength(8),
                                  ]),
                                ),
                              ],
                            ),
                          ),
                          Gap(10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel(label: 'CONFIRM', c: c),
                                Gap(4.h),
                                FormBuilderTextField(
                                  name: 'confirm_password',
                                  obscureText: _obscureConfirm,
                                  textInputAction: TextInputAction.next,
                                  style: tt.bodyLarge!.copyWith(
                                    color: c.text1,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Re-enter',
                                    prefixIcon: Icon(Iconsax.lock_1, size: 16.r),
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 12.h, horizontal: 14.w,
                                    ),
                                    suffixIcon: GestureDetector(
                                      onTap: () => setState(
                                        () =>
                                            _obscureConfirm = !_obscureConfirm,
                                      ),
                                      child: Icon(
                                        _obscureConfirm
                                            ? Iconsax.eye_slash
                                            : Iconsax.eye,
                                        size: 16.r,
                                      ),
                                    ),
                                  ),
                                  validator: (val) {
                                    final pw = _formKey
                                            .currentState
                                            ?.fields['password']
                                            ?.value
                                        as String?;
                                    if (val == null || val.isEmpty) {
                                      return 'Required';
                                    }
                                    if (val != pw) return 'No match';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Gap(4.h),
                      FormBuilderCheckbox(
                        name: 'terms',
                        initialValue: false,
                        contentPadding: EdgeInsets.zero,
                        title: RichText(
                          text: TextSpan(
                            style: tt.bodySmall!.copyWith(
                              color: c.text2,
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Terms',
                                style: tt.bodySmall!.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: c.action,
                                ),
                              ),
                              const TextSpan(text: ' & '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: tt.bodySmall!.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: c.action,
                                ),
                              ),
                            ],
                          ),
                        ),
                        validator: (val) =>
                            val == true ? null : 'Accept the terms to continue',
                      ),
                    ],
                  ),
                ),

                if (authState.errorMessage != null) ...[
                  Gap(6.h),
                  StatusBanner(message: authState.errorMessage!, isError: true),
                ],
                if (authState.infoMessage != null) ...[
                  Gap(6.h),
                  StatusBanner(message: authState.infoMessage!, isError: false),
                ],

                Gap(AppSpacing.md.h),

                AppButton(
                  label: authState.isLoading
                      ? 'Creating account...'
                      : 'Create Account',
                  isLoading: authState.isLoading,
                  onPressed: authState.isLoading ? null : _submit,
                ),

                Gap(12.h),

                Row(
                  children: [
                    Expanded(child: Divider(color: c.border)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      child: Text(
                        'OR',
                        style: tt.bodySmall!.copyWith(
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
                  label: 'Log In',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.go('/login'),
                ),

                Gap(20.h),

                const SocialAuthButtons(),

                Gap(AppSpacing.lg.h),
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
