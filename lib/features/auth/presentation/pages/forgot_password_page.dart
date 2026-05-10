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
    final tt = Theme.of(context).textTheme;
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
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Brand mark ────────────────────────────────────────────────
                Gap(AppSpacing.lg.h),
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
                    shaderCallback: (bounds) =>
                        AppGradients.brandFlame.createShader(bounds),
                    child: Text(
                      'JOBDUN',
                      style: tt.displaySmall!.copyWith(
                        fontSize: 44.sp,
                        letterSpacing: 4.0,
                        height: 1.0,
                        color: Colors.white, // intentional: ShaderMask requires white for gradient
                      ),
                    ),
                  ),
                ),

                Gap(40.h),

                // ── Page heading ──────────────────────────────────────────────
                Text(
                  'RESET YOUR\nPASSWORD.',
                  style: tt.displaySmall!.copyWith(
                    fontSize: 40.sp,
                    letterSpacing: 0.8,
                    color: c.text1,
                    height: 1.05,
                  ),
                ),
                Gap(10.h),
                Text(
                  "Enter your email and we'll send a reset link.",
                  style: tt.bodyLarge!.copyWith(
                    color: c.text2,
                    fontSize: 14.sp,
                  ),
                ),

                Gap(AppSpacing.xl.h),

                // ── Form ─────────────────────────────────────────────────────
                FormBuilder(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EMAIL',
                        style: tt.labelSmall!.copyWith(
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
                        style: tt.bodyLarge!.copyWith(
                          color: c.text1,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'your@email.com',
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

                Gap(AppSpacing.lg.h),

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
                  label: 'Back to log in',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.go('/login'),
                ),

                Gap(AppSpacing.xl.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
