import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../colors.dart';
import '../../theme/app_icons.dart';

/// Standard drag-handle + optional title/close-button header for every
/// Jobdun bottom sheet.
///
/// Usage:
/// ```dart
/// // Drag handle only (simple sheets)
/// BottomSheetHeader()
///
/// // Drag handle + title (picker sheets)
/// BottomSheetHeader(title: 'PICK YOUR COUNTRY')
///
/// // Drag handle + title + close button (dismissible content sheets)
/// BottomSheetHeader(title: 'Filter', onClose: () => Navigator.pop(context))
/// ```
class BottomSheetHeader extends StatelessWidget {
  const BottomSheetHeader({super.key, this.title, this.onClose});

  final String? title;

  /// When provided, an X button appears on the trailing edge. Use for sheets
  /// that don't have an obvious back/done affordance.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final hasTitleRow = title != null || onClose != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle pill — always present.
        Padding(
          padding: EdgeInsets.only(top: 10.h, bottom: hasTitleRow ? 4.h : 10.h),
          child: Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
        ),
        if (hasTitleRow)
          Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, 0, 4.w, 4.h),
            child: Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Text(
                      title!.toUpperCase(),
                      style: tt.labelLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: c.text1,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (onClose != null)
                  IconButton(
                    onPressed: onClose,
                    icon: Icon(
                      AppIcons.closeBox,
                      size: AppIconSize.md.r,
                      color: c.text3,
                    ),
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
