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
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: AnimatedOpacity(
          opacity: _ready ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
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
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFF176),
                          Color(0xFFFFB300),
                          Color(0xFFF97316),
                          Color(0xFFE64A19),
                          Color(0xFFBF360C),
                        ],
                        stops: [0.0, 0.2, 0.5, 0.75, 1.0],
                      ).createShader(bounds),
                      child: Text(
                        'JOBDUN',
                        style: GoogleFonts.oswald(
                          fontSize: 36.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3.0,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                Gap(4.h),
                Center(
                  child: Text(
                    'Create your account',
                    style: GoogleFonts.openSans(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                      color: c.text2,
                    ),
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
                        style: TextStyle(
                          color: c.text1,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Your full name',
                          hintStyle: TextStyle(color: c.text3, fontSize: 13.sp),
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
                        style: TextStyle(
                          color: c.text1,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'your@email.com',
                          hintStyle: TextStyle(color: c.text3, fontSize: 13.sp),
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
                      // Password + Confirm side note on same label row
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
                                  style: TextStyle(
                                    color: c.text1,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Min. 8 chars',
                                    hintStyle: TextStyle(
                                      color: c.text3,
                                      fontSize: 13.sp,
                                    ),
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
                                  style: TextStyle(
                                    color: c.text1,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Re-enter',
                                    hintStyle: TextStyle(
                                      color: c.text3,
                                      fontSize: 13.sp,
                                    ),
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
                            style: GoogleFonts.openSans(
                              fontSize: 11.sp,
                              color: c.text2,
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Terms',
                                style: GoogleFonts.openSans(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: c.action,
                                ),
                              ),
                              const TextSpan(text: ' & '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: GoogleFonts.openSans(
                                  fontSize: 11.sp,
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

                Gap(16.h),

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
                        style: GoogleFonts.openSans(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
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

                Gap(24.h),
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
      style: GoogleFonts.openSans(
        fontSize: 10.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.12 * 11,
        color: c.text2,
      ),
    );
  }
}

