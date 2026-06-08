import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/field_label.dart';

/// Bio / company-story block for the profile page. Renders an eyebrow [label]
/// ("ABOUT" / "ABOUT THE COMPANY") over the free-text [about] copy.
///
/// Empty behaviour depends on [addPrompt]:
///   - `addPrompt == null` (public / how-others-see-you view) → the whole
///     section hides when [about] is blank (design-system: no begging copy).
///   - `addPrompt != null` (the owner's own profile) → an empty bio shows the
///     eyebrow + a tappable Add row routing to `/profile/edit`, so the owner
///     discovers the field and is nudged to fill it.
class ProfileAboutSection extends StatelessWidget {
  const ProfileAboutSection({
    super.key,
    required this.about,
    required this.label,
    this.addPrompt,
  });

  final String? about;
  final String label;

  /// Owner-only Add affordance shown when [about] is blank. Null = hide.
  final String? addPrompt;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final copy = about?.trim() ?? '';

    if (copy.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          Gap(AppSpacing.sm.h),
          Text(
            copy,
            style: tt.bodyLarge!.copyWith(color: c.text2, height: 1.55),
          ),
        ],
      );
    }

    final prompt = addPrompt;
    if (prompt == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        Gap(AppSpacing.sm.h),
        InkWell(
          onTap: () => context.push('/profile/edit'),
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            child: Row(
              children: [
                Icon(
                  AppIcons.add,
                  size: AppIconSize.inline.r,
                  color: c.actionInk,
                ),
                Gap(8.w),
                Expanded(
                  child: Text(
                    prompt,
                    style: tt.bodyMedium!.copyWith(
                      color: c.actionInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  AppIcons.chevronRight,
                  size: AppIconSize.inline.r,
                  color: c.actionInk,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
