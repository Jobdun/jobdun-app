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

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
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
    ref.read(authControllerProvider.notifier).signIn(
      email: values['email'] as String,
      password: values['password'] as String,
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
                  'WELCOME BACK',
                  style: GoogleFonts.barlow(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.12 * 11,
                    color: AppColors.text3,
                  ),
                ),
                Gap(8.h),
                Text(
                  'Sign in.',
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
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _continue(),
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
                        validator: FormBuilderValidators.required(),
                      ),
                      Gap(8.h),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.go('/forgot-password'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.text2,
                            padding: EdgeInsets.zero,
                            minimumSize: Size(0, 36.h),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Forgot password',
                            style: GoogleFonts.barlow(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w400,
                              color: AppColors.text2,
                            ),
                          ),
                        ),
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
                  label: authState.isLoading ? 'Signing in...' : 'Sign in',
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
                      'No account?',
                      style: GoogleFonts.barlow(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.text2,
                      ),
                    ),
                    Gap(4.w),
                    GestureDetector(
                      onTap: () => context.go('/register'),
                      child: Text(
                        'Create one.',
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
