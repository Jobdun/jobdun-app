import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../app/theme/app_colors.dart';

/// The app's filter pill — one tap target, one selected state.
///
/// Drawn on the Figma refresh (`JobDun-Screens` → Applicants, node 122:5089):
/// a 40dp pill, orange fill when selected, otherwise unfilled behind a
/// `borderStrong` hairline. Labels are passed in their natural case — the
/// mock reads "All · 4", not "ALL · 4" — so this widget no longer uppercases
/// them.
class GvChip extends StatelessWidget {
  const GvChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: active,
      label: '$label filter, ${active ? "selected" : "not selected"}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          height: 44.h,
          child: Center(
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: Curves.ease,
              height: 40.h,
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? c.action : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.btn.r),
                // borderStrong on the unselected pill: it is an interactive
                // control edge and owes the 3:1 floor (MASTER → Accessibility).
                border: Border.all(color: active ? c.action : c.borderStrong),
              ),
              child: Text(
                label,
                style: tt.titleMedium!.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  color: active ? c.onAction : c.text2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
