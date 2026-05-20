import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import 'j_button.dart';

/// SafeArea-aware bottom CTA bar — the canonical chrome for screen-level
/// primary actions ("SAVE CHANGES", "POST JOB", "APPLY NOW",
/// "SUBMIT APPLICATION").
///
/// **Layout.** Surface-tinted background with a 1px top border (matches
/// MASTER §240 — borders instead of shadows). Padded 20w/12h, then the
/// [primary] [JButton] stretched to fill. If [secondary] is provided, the
/// row reads `secondary | primary` (left-to-right), each expanded — matches
/// `logout_confirm_sheet.dart` precedent.
///
/// **SafeArea.** Wraps the contents in a bottom-only `SafeArea` so the bar
/// stays clear of the home-indicator on devices without a hardware home
/// button.
///
/// **Heights.** Caller controls the button height via [JButton.size]; this
/// widget does not impose one. For a single full-width CTA pass
/// `JButtonSize.standard` (56h, MASTER §110).
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.primary, this.secondary});

  final JButton primary;
  final JButton? secondary;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
          child: secondary == null
              ? primary
              : Row(
                  children: [
                    Expanded(child: secondary!),
                    Gap(AppSpacing.md.w),
                    Expanded(child: primary),
                  ],
                ),
        ),
      ),
    );
  }
}
