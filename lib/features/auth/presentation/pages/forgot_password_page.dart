import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/jobdun_logo.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
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
          icon: Icon(AppIcons.back, size: 22.r, color: c.text2),
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
                // Compact wordmark — user is mid-flow, they know the app.
                // Full lockup is reserved for splash + login (T3.2).
                Gap(24.h),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      JobdunLogo(variant: LogoVariant.mark, height: 24.r),
                      Gap(8.w),
                      Text(
                        'JOBDUN',
                        style: tt.displaySmall!.copyWith(
                          fontSize: 18.sp,
                          letterSpacing: 1.5,
                          height: 1.0,
                          color: c.text1,
                        ),
                      ),
                    ],
                  ),
                ),

                Gap(32.h),

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
                  child: JTextField(
                    name: 'email',
                    label: 'Email',
                    hint: 'your@email.com',
                    prefixIcon: AppIcons.email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    onSubmitted: (_) => _submit(),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(
                        errorText: 'Email is required.',
                      ),
                      FormBuilderValidators.email(
                        errorText: 'Enter a valid email.',
                      ),
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

                Gap(AppSpacing.lg.h),

                JButton(
                  label: authState.isLoading ? 'SENDING...' : 'SEND RESET LINK',
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

                JButton(
                  label: 'BACK TO LOG IN',
                  variant: JButtonVariant.secondary,
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
