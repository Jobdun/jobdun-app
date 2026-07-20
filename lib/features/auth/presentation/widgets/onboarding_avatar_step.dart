import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/avatar_block.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/utils/string_utils.dart';

/// Step 3 of [OnboardingCompletionSheet] — optional avatar pick + finish.
/// Extracted from the sheet to keep that file under the size budget.
class OnboardingAvatarStep extends StatelessWidget {
  const OnboardingAvatarStep({
    super.key,
    required this.pickedFile,
    required this.name,
    required this.submitting,
    required this.onBack,
    required this.onCamera,
    required this.onGallery,
    required this.onSkip,
    required this.onFinish,
    this.stepLabel = 'STEP 3 OF 3',
  });

  final File? pickedFile;
  final String name;
  final bool submitting;
  // Null when this is the first step in the sheet's plan — no back arrow.
  final VoidCallback? onBack;
  final String stepLabel;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onSkip;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final initials = StringUtils.initials(name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (onBack != null) ...[
              InkWell(
                onTap: submitting ? null : onBack,
                child: Padding(
                  padding: EdgeInsets.all(4.r),
                  child: Icon(
                    AppIcons.back,
                    size: AppIconSize.md.r,
                    color: c.text2,
                  ),
                ),
              ),
              Gap(8.w),
            ],
            Text(
              stepLabel,
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
          'Add a profile photo?',
          style: tt.headlineSmall!.copyWith(color: c.text1),
        ),
        Gap(6.h),
        Text(
          'Optional — but profiles with photos get more replies.',
          style: tt.bodyMedium!.copyWith(color: c.text2),
        ),
        Gap(AppSpacing.lg.h),
        Center(
          child: GestureDetector(
            onTap: submitting ? null : onGallery,
            child: pickedFile == null
                ? AvatarBlock(initials: initials, size: 120)
                : ClipOval(
                    child: Image.file(
                      pickedFile!,
                      width: 120.r,
                      height: 120.r,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
        ),
        Gap(AppSpacing.md.h),
        Row(
          children: [
            Expanded(
              child: JButton(
                label: 'CAMERA',
                variant: JButtonVariant.secondary,
                onPressed: submitting ? null : onCamera,
              ),
            ),
            Gap(12.w),
            Expanded(
              child: JButton(
                label: 'GALLERY',
                variant: JButtonVariant.secondary,
                onPressed: submitting ? null : onGallery,
              ),
            ),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: JButton(
                label: 'SKIP',
                variant: JButtonVariant.secondary,
                onPressed: submitting ? null : onSkip,
              ),
            ),
            Gap(12.w),
            Expanded(
              child: JButton(
                label: submitting ? 'FINISHING…' : 'FINISH',
                isLoading: submitting,
                onPressed: submitting ? null : onFinish,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
