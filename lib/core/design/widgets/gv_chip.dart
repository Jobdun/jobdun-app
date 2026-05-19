import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../app/theme/app_colors.dart';

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
        onTap: onTap,
        child: SizedBox(
          height: 44.h,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.ease,
              height: 30.h,
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? c.action : c.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.chip.r),
                border: Border.all(color: active ? c.action : c.border),
              ),
              child: Text(
                label.toUpperCase(),
                style: tt.labelMedium!.copyWith(
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
