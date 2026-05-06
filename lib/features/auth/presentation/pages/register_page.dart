import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/theme/app_colors.dart';
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
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _continue() {
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
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: AnimatedOpacity(
          opacity: _ready ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 100),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Gap(48.h),
                Center(
                  child: SvgPicture.asset(
                    'lib/core/assets/mark-jobdun.svg',
                    width: 48.r,
                    height: 48.r,
                  ),
                ),
                Gap(32.h),
                Text(
                  'NEW ACCOUNT',
                  style: GoogleFonts.barlow(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.12 * 11,
                    color: AppColors.text3,
                  ),
                ),
                Gap(8.h),
                Text(
                  'Create account.',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.02 * 28,
                    color: AppColors.text1,
                  ),
                ),
                Gap(32.h),
                FormBuilder(
                  key: _formKey,
                  child: Column(
                    children: [
                      FormBuilderTextField(
                        name: 'full_name',
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Iconsax.user, size: 20.r),
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.minLength(2),
                        ]),
                      ),
                      Gap(12.h),
                      FormBuilderTextField(
                        name: 'email',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(Iconsax.sms, size: 20.r),
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.email(),
                        ]),
                      ),
                      Gap(12.h),
                      FormBuilderTextField(
                        name: 'password',
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Iconsax.lock, size: 20.r),
                          suffixIcon: GestureDetector(
                            onTap: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            child: Icon(
                              _obscurePassword
                                  ? Iconsax.eye_slash
                                  : Iconsax.eye,
                              size: 20.r,
                            ),
                          ),
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.minLength(8),
                        ]),
                      ),
                      Gap(4.h),
                      FormBuilderCheckbox(
                        name: 'terms',
                        initialValue: false,
                        activeColor: AppColors.foundation,
                        title: RichText(
                          text: TextSpan(
                            style: GoogleFonts.barlow(
                              fontSize: 13.sp,
                              color: AppColors.text2,
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Terms of Service',
                                style: GoogleFonts.barlow(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.action,
                                ),
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: GoogleFonts.barlow(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.action,
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
                Gap(8.h),
                if (authState.errorMessage != null) ...[
                  StatusBanner(message: authState.errorMessage!, isError: true),
                  Gap(8.h),
                ],
                if (authState.infoMessage != null) ...[
                  StatusBanner(message: authState.infoMessage!, isError: false),
                  Gap(8.h),
                ],
                Gap(12.h),
                AppButton(
                  label: authState.isLoading ? 'Creating account...' : 'Create account',
                  isLoading: authState.isLoading,
                  onPressed: authState.isLoading ? null : _continue,
                ),
                Gap(24.h),
                const SocialAuthButtons(),
                Gap(24.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: GoogleFonts.barlow(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.text2,
                      ),
                    ),
                    Gap(4.w),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Text(
                        'Sign in.',
                        style: GoogleFonts.barlow(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.action,
                        ),
                      ),
                    ),
                  ],
                ),
                Gap(16.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
