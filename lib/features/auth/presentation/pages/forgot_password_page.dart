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
    final c = context.c;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        leading: IconButton(
          onPressed: () => context.go('/login'),
          icon: Icon(Iconsax.arrow_left, size: 22.r, color: c.text2),
        ),
      ),
      body: SafeArea(
        child: AnimatedOpacity(
          opacity: _ready ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Brand mark ────────────────────────────────────────────────
                Gap(24.h),
                Center(
                  child: SvgPicture.asset(
                    'lib/core/assets/mark-jobdun.svg',
                    width: 52.r,
                    height: 52.r,
                    colorFilter: ColorFilter.mode(c.action, BlendMode.srcIn),
                  ),
                ),
                Gap(12.h),
                Center(
                  child: ShaderMask(
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
                        fontSize: 44.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4.0,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),

                Gap(40.h),

                // ── Page heading ──────────────────────────────────────────────
                Text(
                  'RESET YOUR\nPASSWORD.',
                  style: GoogleFonts.oswald(
                    fontSize: 40.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: c.text1,
                    height: 1.05,
                  ),
                ),
                Gap(10.h),
                Text(
                  "Enter your email and we'll send a reset link.",
                  style: GoogleFonts.openSans(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: c.text2,
                    height: 1.6,
                  ),
                ),

                Gap(32.h),

                // ── Form ─────────────────────────────────────────────────────
                FormBuilder(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EMAIL',
                        style: GoogleFonts.openSans(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.12 * 11,
                          color: c.text2,
                        ),
                      ),
                      Gap(6.h),
                      FormBuilderTextField(
                        name: 'email',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        style: TextStyle(
                          color: c.text1,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'your@email.com',
                          hintStyle: TextStyle(color: c.text3, fontSize: 14.sp),
                          prefixIcon: Icon(Iconsax.sms, size: 18.r),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 16.h, horizontal: 16.w,
                          ),
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.email(),
                        ]),
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
                  StatusBanner(
                    message: authState.infoMessage!,
                    isError: false,
                  ),
                  Gap(8.h),
                ],

                Gap(24.h),

                AppButton(
                  label: authState.isLoading ? 'Sending...' : 'Send reset link',
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
                  label: 'Back to log in',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.go('/login'),
                ),

                Gap(32.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
