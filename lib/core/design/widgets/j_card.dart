import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import 'field_label.dart';

/// Generic chrome card — eyebrow-titled, bordered surface that hosts a list
/// of children separated visually from the title by a 1px divider.
///
/// **Scope.** This is a *chrome* card. Feature cards with their own layout
/// (e.g. `JobCard`, `TradieCard` in this directory) are not built on top of
/// [JCard] — they own their own composition.
///
/// **Title.** Uses [FieldLabel] for the eyebrow — same letter-spacing, same
/// muted `c.text3` colour. If you find yourself needing a louder title,
/// you're probably looking for a [PageHeader] one layer up, not a brighter
/// [JCard].
class JCard extends StatelessWidget {
  const JCard({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md.w,
              14.h,
              AppSpacing.md.w,
              10.h,
            ),
            child: FieldLabel(title),
          ),
          Divider(height: 1, color: c.border),
          ...children,
        ],
      ),
    );
  }
}

/// Single stat tile — icon + bold value + uppercased label. Drops into a
/// `Row` of three on the profile dashboard ("RATING", "JOBS DONE",
/// "YRS EXP", etc.).
///
/// Wraps itself in [Expanded] so callers can drop a series of [JStatBadge]s
/// directly into a `Row` without each one repeating the wrap.
///
/// **Internal label note.** The label uses an 11sp / w600 / ls 0.5 / c.text2
/// treatment that is *close to* but not identical to the theme's
/// `labelMedium` (12sp, same weight/spacing/colour). Preserved as-is to
/// avoid a visual regression on the profile dashboard; revisit when the
/// stat-tile layout is next touched.
class JStatBadge extends StatelessWidget {
  const JStatBadge({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: AppIconSize.md.r, color: iconColor),
            Gap(6.h),
            Text(
              value,
              // On-scale stat number — headlineMedium (24sp), matching the home
              // stat cards (was an off-scale 22sp override on headlineSmall).
              style: tt.headlineMedium!.copyWith(
                fontWeight: FontWeight.w900,
                color: c.text1,
              ),
            ),
            Gap(1.h),
            Text(
              label.toUpperCase(),
              style: tt.labelSmall!.copyWith(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: c.text2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
