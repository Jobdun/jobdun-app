import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';

/// Back caret plus screen title, shared by every auth screen.
///
/// Figma `JobDun-Screens` → Login (nodes 100:2025 / 100:2029) puts the same
/// 67dp bar at the top of both frames: a chevron at the 16dp margin, then the
/// title in Inter Bold 24. The title carries the role on signup
/// ("Create Account - Hiring"), which is the only cue that a role was chosen
/// upstream — so it is a required parameter rather than a default.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, this.onBack});

  final String title;

  /// null hides the caret and left-aligns the title on the same margin. Pass
  /// null only when the screen is genuinely the root of its stack; a caret
  /// that pops nothing is worse than no caret.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return SizedBox(
      height: 67.h,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
        child: Row(
          children: [
            if (onBack != null) ...[
              Semantics(
                button: true,
                label: 'Back',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onBack,
                  // The caret is only ~10dp of ink; the padding is what makes
                  // it a 44dp target.
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm.w,
                      vertical: 12.h,
                    ),
                    child: Icon(
                      AppIcons.back,
                      size: AppIconSize.md.r,
                      color: c.text1,
                    ),
                  ),
                ),
              ),
              Gap(AppSpacing.sm.w),
            ],
            Expanded(
              child: Text(
                title,
                style: tt.titleMedium!.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: c.text1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
