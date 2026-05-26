import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../providers/verifications_provider.dart';

/// One-time consent sheet shown when a builder toggles
/// `[ Verified workers only ]` OFF for the first time. Writes a row to
/// `builder_unverified_acknowledgements` (via the provider) on confirm;
/// checked on subsequent toggles to skip the dialog.
class UnverifiedConsentDialog {
  const UnverifiedConsentDialog._();

  /// Shows the dialog. Returns `true` if the user accepted, `false` if they
  /// cancelled (caller should leave the filter ON).
  static Future<bool> show(BuildContext context, WidgetRef ref) async {
    final accepted = await showJSheet<bool>(
      context: context,
      builder: (ctx) => const _SheetBody(),
    );
    if (accepted != true) return false;
    await ref.read(builderAcknowledgementProvider.notifier).markAcknowledged();
    return true;
  }

  /// Checks whether this builder has already acknowledged.
  static Future<bool> hasAcknowledged(WidgetRef ref) =>
      ref.read(builderAcknowledgementProvider.notifier).isAcknowledged();
}

class _SheetBody extends StatelessWidget {
  const _SheetBody();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You\'re including unverified workers',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: c.text1,
            ),
          ),
          Gap(12.h),
          Text(
            'Unverified workers haven\'t been checked against the '
            'government register. We don\'t know if their licence is '
            'current or even real.\n\nHiring them is your call — and '
            'your risk.',
            style: TextStyle(fontSize: 14.sp, color: c.text2, height: 1.45),
          ),
          Gap(20.h),
          Row(
            children: [
              Expanded(
                child: JButton(
                  label: 'GO BACK',
                  variant: JButtonVariant.secondary,
                  size: JButtonSize.standard,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              Gap(12.w),
              Expanded(
                child: JButton(
                  label: 'I UNDERSTAND',
                  variant: JButtonVariant.primary,
                  size: JButtonSize.standard,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
