import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../providers/auth_provider.dart';

Future<void> showLogoutSheet(BuildContext context, WidgetRef ref) {
  return showMaterialModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _LogoutSheet(ref: ref),
  );
}

class _LogoutSheet extends StatelessWidget {
  const _LogoutSheet({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card.r * 2),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg.w,
        AppSpacing.md.h,
        AppSpacing.lg.w,
        AppSpacing.xl.h + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // drag handle
          Center(
            child: Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          Gap(AppSpacing.lg.h),
          Text(
            'SIGN OUT?',
            style: tt.headlineSmall!.copyWith(letterSpacing: 1.5),
          ),
          Gap(8.h),
          Text(
            "You'll be signed out of your account on this device.",
            style: tt.bodyMedium!.copyWith(color: c.text2),
          ),
          Gap(AppSpacing.xl.h),
          Row(
            children: [
              Expanded(
                child: JButton(
                  label: 'CANCEL',
                  variant: JButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Gap(AppSpacing.md.w),
              Expanded(
                child: JButton(
                  label: 'SIGN OUT',
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(authControllerProvider.notifier).signOut();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
