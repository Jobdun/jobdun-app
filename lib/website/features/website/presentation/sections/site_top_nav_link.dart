import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';

/// A single scroll-anchor link in the site top bar.
///
/// Two states: idle (text2 colour, weight 600) and active (text1 colour, a
/// short orange rule underneath, weight 700). The orange rule uses a 1px
/// `border-bottom` rather than a `border-left` accent stripe — Jobdun's
/// design system bans side-stripes, and a centered underline reads as a
/// tab indicator (which is what an active nav item is).
class SiteTopNavLink extends StatelessWidget {
  const SiteTopNavLink({
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
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.btn.r),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.xs.w,
            vertical: AppSpacing.xs.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: tt.labelLarge!.copyWith(
                  color: active ? c.text1 : c.text2,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              Gap(AppSpacing.xs.h),
              SizedBox(
                width: 24.w,
                height: 2.h,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: active ? c.action : Colors.transparent,
                    borderRadius: BorderRadius.circular(1.r),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
