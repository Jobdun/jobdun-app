import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../../core/design/widgets/j_button.dart';

/// Unsaved-changes confirm shared by every quick-edit sheet and the About
/// editor. Returns true when the user chose to discard.
Future<bool> showDiscardChangesSheet(BuildContext context) async {
  final discard = await showJSheet<bool>(
    context: context,
    backgroundColor: context.c.card,
    builder: (sheetCtx) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discard your changes?',
              style: Theme.of(
                sheetCtx,
              ).textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w700),
            ),
            Gap(8.h),
            Text(
              "You've edited your profile but haven't saved.",
              style: Theme.of(sheetCtx).textTheme.bodyMedium,
            ),
            Gap(16.h),
            SizedBox(
              width: double.infinity,
              child: JButton(
                label: 'KEEP EDITING',
                variant: JButtonVariant.primary,
                onPressed: () => Navigator.of(sheetCtx).pop(false),
              ),
            ),
            Gap(8.h),
            SizedBox(
              width: double.infinity,
              child: JButton(
                label: 'DISCARD CHANGES',
                variant: JButtonVariant.secondary,
                onPressed: () => Navigator.of(sheetCtx).pop(true),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return discard ?? false;
}
