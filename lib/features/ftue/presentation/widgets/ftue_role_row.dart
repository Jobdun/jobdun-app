import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';

/// One tappable role inside [FtueRoleSheet]: a filled 40dp disc, a title, a
/// one-line promise, and a chevron.
///
/// Figma `JobDun-Screens` → Onboard (node 30:8124) distinguishes the two roles
/// by the disc alone — orange for "Find Work", near-black for "Hire Workers".
/// Both are expressed as tokens so the pair inverts correctly on dark, where a
/// literal #181818 disc would vanish into the surface:
///
/// * [FtueRoleRow.accent] — `c.action` disc, `c.onAction` glyph.
/// * [FtueRoleRow.inverse] — `c.text1` disc, `c.surface` glyph.
class FtueRoleRow extends StatelessWidget {
  const FtueRoleRow.accent({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = false,
  }) : isAccent = true;

  const FtueRoleRow.inverse({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = false,
  }) : isAccent = false;

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isAccent;

  /// Hairline under the row — the sheet stacks two rows and only the first
  /// carries the separator.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: InkWell(
        onTap: onTap,
        splashColor: c.action.withValues(alpha: 0.12),
        highlightColor: c.action.withValues(alpha: 0.06),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: c.border))
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md.w),
            child: Row(
              children: [
                Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    color: isAccent ? c.action : c.text1,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: AppIconSize.md.r,
                    color: isAccent ? c.onAction : c.surface,
                  ),
                ),
                Gap(AppSpacing.md.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: tt.titleMedium!.copyWith(
                          color: c.text1,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      Gap(AppSpacing.xs.h),
                      Text(
                        subtitle,
                        style: tt.bodyMedium!.copyWith(
                          color: c.text2,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Gap(AppSpacing.sm.w),
                Icon(
                  AppIcons.chevronRight,
                  size: AppIconSize.md.r,
                  color: c.text3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
