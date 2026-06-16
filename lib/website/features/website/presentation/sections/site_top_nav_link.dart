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
///
/// On desktop, hovering an inactive link lifts the label to text1 and fades a
/// half-strength orange underline in (150ms). The font weight never changes on
/// hover — only colour — so the row can't reflow under the pointer.
class SiteTopNavLink extends StatefulWidget {
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
  State<SiteTopNavLink> createState() => _SiteTopNavLinkState();
}

class _SiteTopNavLinkState extends State<SiteTopNavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final active = widget.active;

    final labelColor = active ? c.text1 : (_hovered ? c.text1 : c.text2);
    final labelWeight = active ? FontWeight.w700 : FontWeight.w600;
    final underlineColor = active
        ? c.action
        : (_hovered ? c.action.withValues(alpha: 0.4) : Colors.transparent);

    final motion = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 150);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        button: true,
        selected: active,
        label: widget.label,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppRadius.btn.r),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.xs.w,
              vertical: AppSpacing.xs.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: motion,
                  style: tt.labelLarge!.copyWith(
                    color: labelColor,
                    fontWeight: labelWeight,
                  ),
                  child: Text(widget.label),
                ),
                Gap(AppSpacing.xs.h),
                AnimatedContainer(
                  duration: motion,
                  width: 24.w,
                  height: 2.h,
                  decoration: BoxDecoration(
                    color: underlineColor,
                    borderRadius: BorderRadius.circular(1.r),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
