import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
import '../../domain/entities/user_role.dart';

/// Step 2 of [OnboardingCompletionSheet] — confirm/enter the display name.
/// Extracted from the sheet to keep that file under the size budget.
class OnboardingNameStep extends StatelessWidget {
  const OnboardingNameStep({
    super.key,
    required this.controller,
    required this.role,
    required this.onBack,
    required this.onContinue,
  });

  final TextEditingController controller;
  final UserRole? role;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  String get _explanation => role == UserRole.builder
      ? 'Trades see this on your job posts and messages.'
      : 'Builders see this on your applications and profile.';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            InkWell(
              onTap: onBack,
              child: Padding(
                padding: EdgeInsets.all(4.r),
                child: Icon(AppIcons.back, size: 18.r, color: c.text2),
              ),
            ),
            Gap(8.w),
            Text(
              'STEP 2 OF 3',
              style: tt.labelSmall!.copyWith(
                color: c.text3,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Gap(8.h),
        Text(
          'What should we call you?',
          style: tt.headlineMedium!.copyWith(color: c.text1, fontSize: 22.sp),
        ),
        Gap(6.h),
        Text(_explanation, style: tt.bodyMedium!.copyWith(color: c.text2)),
        Gap(AppSpacing.lg.h),
        Text(
          'YOUR NAME',
          style: tt.labelSmall!.copyWith(
            color: c.text3,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        Gap(6.h),
        JTextField(
          name: 'display_name',
          hint: 'e.g. Sam Wilson',
          controller: controller,
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: JButton(label: 'CONTINUE', onPressed: onContinue),
        ),
      ],
    );
  }
}
