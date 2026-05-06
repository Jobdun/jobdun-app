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

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormBuilderState>();
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
    final email = _formKey.currentState!.value['email'] as String;
    ref.read(authControllerProvider.notifier).sendPasswordReset(email);
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
                  'FORGOT PASSWORD',
                  style: GoogleFonts.barlow(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.12 * 11,
                    color: AppColors.text3,
                  ),
                ),
                Gap(8.h),
                Text(
                  'Reset password.',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.02 * 28,
                    color: AppColors.text1,
                  ),
                ),
                Gap(8.h),
                Text(
                  "Enter your email and we'll send a reset link.",
                  style: GoogleFonts.barlow(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.text2,
                    height: 1.7,
                  ),
                ),
                Gap(32.h),
                FormBuilder(
                  key: _formKey,
                  child: FormBuilderTextField(
                    name: 'email',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Iconsax.sms, size: 20.r),
                    ),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                      FormBuilderValidators.email(),
                    ]),
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
                  label: authState.isLoading ? 'Sending...' : 'Send reset link',
                  isLoading: authState.isLoading,
                  onPressed: authState.isLoading ? null : _submit,
                ),
                Gap(12.h),
                AppButton(
                  label: 'Back to sign in',
                  variant: AppButtonVariant.text,
                  onPressed: () => context.go('/login'),
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
