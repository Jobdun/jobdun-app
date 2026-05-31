import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';

/// Inner widgets for [WizardLicenceStep]. Lifted into a sibling file so the
/// parent stays under the 500-LOC ceiling. Public scoping is intentional —
/// `_Prefixed` would block import.

class LicenceSupportedForm extends StatelessWidget {
  const LicenceSupportedForm({
    super.key,
    required this.formKey,
    required this.calling,
    required this.state,
    required this.errorMessage,
    required this.onVerify,
    required this.onSkip,
  });

  final GlobalKey<FormBuilderState> formKey;
  final bool calling;
  final String state;
  final String? errorMessage;
  final VoidCallback onVerify;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormBuilder(
          key: formKey,
          child: JTextField(
            name: 'licence_number',
            label: 'Licence number',
            hint: 'e.g. EL-12345',
            enabled: !calling,
          ),
        ),
        if (errorMessage != null) ...[
          Gap(8.h),
          Text(
            errorMessage!,
            style: TextStyle(fontSize: 13.sp, color: c.urgent),
          ),
        ],
        Gap(16.h),
        if (calling)
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Row(
              children: [
                SizedBox(
                  width: 16.r,
                  height: 16.r,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                Gap(12.w),
                Expanded(
                  child: Text(
                    'Checking with $state Fair Trading\'s public register…',
                    style: TextStyle(fontSize: 13.sp, color: c.text2),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: JButton(
                label: 'SKIP',
                variant: JButtonVariant.secondary,
                size: JButtonSize.standard,
                onPressed: calling ? null : onSkip,
              ),
            ),
            Gap(12.w),
            Expanded(
              child: JButton(
                label: 'VERIFY',
                variant: JButtonVariant.primary,
                size: JButtonSize.standard,
                onPressed: calling ? null : onVerify,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class LicenceUnsupportedHint extends StatelessWidget {
  const LicenceUnsupportedHint({
    super.key,
    required this.state,
    required this.onUpload,
    required this.onSkip,
  });

  final String state;
  final Future<void> Function({String? prefilledNumber}) onUpload;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: c.actionBg,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: c.action.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.info, size: AppIconSize.md.r, color: c.action),
              Gap(8.w),
              Text(
                'No automated check for $state yet',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: c.text1,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          Gap(8.h),
          Text(
            'Upload a clear photo of your licence and a reviewer will '
            'confirm it within 24 hours. Or pick a different state above.',
            style: TextStyle(fontSize: 13.sp, color: c.text2, height: 1.45),
          ),
          Gap(14.h),
          Row(
            children: [
              Expanded(
                child: JButton(
                  label: 'SKIP',
                  variant: JButtonVariant.secondary,
                  size: JButtonSize.standard,
                  onPressed: onSkip,
                ),
              ),
              Gap(12.w),
              Expanded(
                child: JButton(
                  label: 'UPLOAD DOCUMENT',
                  variant: JButtonVariant.primary,
                  size: JButtonSize.standard,
                  onPressed: () => onUpload(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LicencePhoneRequired extends StatelessWidget {
  const LicencePhoneRequired({
    super.key,
    required this.detail,
    required this.onBack,
  });

  final String detail;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verify your phone first',
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: c.text1,
          ),
        ),
        Gap(12.h),
        Text(
          detail,
          style: TextStyle(fontSize: 14.sp, color: c.text2, height: 1.45),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: JButton(
            label: 'VERIFY MY PHONE',
            variant: JButtonVariant.primary,
            size: JButtonSize.standard,
            onPressed: () => context.push('/profile/verify-phone'),
          ),
        ),
        Gap(12.h),
        SizedBox(
          width: double.infinity,
          child: JButton(
            label: 'BACK',
            variant: JButtonVariant.secondary,
            size: JButtonSize.standard,
            onPressed: onBack,
          ),
        ),
      ],
    );
  }
}

class LicenceDropdownRow extends StatelessWidget {
  const LicenceDropdownRow({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: c.text3,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        Gap(6.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: c.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              dropdownColor: c.surface,
              style: TextStyle(fontSize: 14.sp, color: c.text1),
              items: items
                  .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                  .toList(),
              onChanged: (v) => v == null ? null : onChanged(v),
            ),
          ),
        ),
      ],
    );
  }
}
