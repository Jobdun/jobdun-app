import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../domain/entities/user_role.dart';

/// Step 1 of [OnboardingCompletionSheet] — the builder/trade role pick.
/// Extracted from the sheet to keep that file under the size budget.
class OnboardingRoleStep extends StatelessWidget {
  const OnboardingRoleStep({
    super.key,
    required this.selected,
    required this.disabled,
    required this.onPick,
  });

  final UserRole? selected;
  final bool disabled;
  final void Function(UserRole) onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'WELCOME TO JOBDUN',
          style: tt.labelSmall!.copyWith(
            color: c.text3,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        Gap(8.h),
        Text(
          'Which side are you on?',
          style: tt.headlineMedium!.copyWith(color: c.text1, fontSize: 22.sp),
        ),
        Gap(6.h),
        Text(
          'About 20 seconds to finish setting up.',
          style: tt.bodyMedium!.copyWith(color: c.text2),
        ),
        Gap(AppSpacing.lg.h),
        _RoleCard(
          icon: AppIcons.builder,
          label: "I'M HIRING",
          description: 'Post jobs, review applicants, manage crews.',
          selected: selected == UserRole.builder,
          disabled: disabled,
          onTap: () => onPick(UserRole.builder),
        ),
        Gap(12.h),
        _RoleCard(
          icon: AppIcons.briefcase,
          label: "I'M LOOKING FOR WORK",
          description: 'Browse jobs, apply, get hired.',
          selected: selected == UserRole.trade,
          disabled: disabled,
          onTap: () => onPick(UserRole.trade),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(AppSpacing.lg.r),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(
            color: selected ? c.action : c.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44.r,
              height: 44.r,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? c.action : c.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.avatar.r),
              ),
              child: Icon(
                icon,
                size: 22.r,
                // intentional: white-on-action when selected
                color: selected ? Colors.white : c.text2,
              ),
            ),
            Gap(AppSpacing.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.labelLarge!.copyWith(
                      color: c.text1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Gap(4.h),
                  Text(
                    description,
                    style: tt.bodySmall!.copyWith(
                      color: c.text2,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            Gap(AppSpacing.sm.w),
            Icon(
              AppIcons.chevronRight,
              size: 18.r,
              color: selected ? c.action : c.text3,
            ),
          ],
        ),
      ),
    );
  }
}
