import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';

/// Variant of [JButton] — picks the background/foreground role.
///
/// - [primary]   filled orange CTA, white fg. Use for the dominant action on
///               a screen (LOG IN, APPLY NOW, POST JOB).
/// - [secondary] filled slate, primary-text fg. Use for the second action in
///               a pair (CANCEL beside CONFIRM, RESEND beside CONTINUE).
/// - [text]      no background, orange fg. Use sparingly — typically inline
///               affordances (e.g. "Skip" on FTUE pages).
enum JButtonVariant { primary, secondary, text }

/// Size of [JButton] — picks the minimum height.
///
/// - [standard] 56dp. MASTER §110. Use for bottom-bar CTAs and full-width
///              primary actions.
/// - [compact]  40dp. Use for in-row actions (applications page REJECT /
///              SHORTLIST / HIRE), header trailing chips. Never as the
///              dominant CTA on a screen.
enum JButtonSize { standard, compact }

/// Canonical primary button for Jobdun. Replaces the v1 [AppButton] and is
/// the only button widget allowed in `lib/features/`.
///
/// **Casing:** Pass labels already uppercased. This widget intentionally does
/// not call `.toUpperCase()` — the casing convention is enforced at the call
/// site so a future `lint` can catch lowercase regressions (see
/// `scripts/check-design-system.sh`).
///
/// **Press overlay:** Primary uses a white wash; secondary and text use an
/// orange wash. `FilledButton` does not consume `elevatedButtonTheme`, so the
/// overlay is set on this widget directly rather than relying on the theme.
class JButton extends StatelessWidget {
  const JButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = JButtonVariant.primary,
    this.size = JButtonSize.standard,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final JButtonVariant variant;
  final JButtonSize size;
  final bool isLoading;
  final IconData? icon;

  double get _minHeight => switch (size) {
    JButtonSize.standard => 56.h,
    JButtonSize.compact => 40.h,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    final labelStyle = tt.labelLarge!.copyWith(color: _labelColor(c));

    final Widget content = isLoading
        ? SizedBox.square(
            dimension: 18.r,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _loaderColor(c),
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppIconSize.inline.r),
                Gap(8.w),
              ],
              // Flexible + ellipsis: when a parent gives the button a tight
              // width (e.g. JButton inside a Row with sibling actions), the
              // label shrinks gracefully instead of overflowing — every
              // builder screen ran into this on narrow phones.
              Flexible(
                child: Text(
                  label,
                  style: labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    return switch (variant) {
      JButtonVariant.primary => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: c.action,
          foregroundColor: c.onAction,
          disabledBackgroundColor: c.action.withValues(alpha: 0.35),
          disabledForegroundColor: c.onAction.withValues(alpha: 0.5),
          minimumSize: Size.fromHeight(_minHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.btn.r),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ).copyWith(overlayColor: _overlay(_primaryOverlayBase)),
        child: content,
      ),
      JButtonVariant.secondary => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: c.surfaceRaised,
          foregroundColor: c.text1,
          disabledBackgroundColor: c.surfaceRaised.withValues(alpha: 0.5),
          disabledForegroundColor: c.text2,
          minimumSize: Size.fromHeight(_minHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.btn.r),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ).copyWith(overlayColor: _overlay(c.action)),
        child: content,
      ),
      JButtonVariant.text => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: c.action,
          minimumSize: Size.fromHeight(
            size == JButtonSize.standard ? 44.h : 36.h,
          ),
        ).copyWith(overlayColor: _overlay(c.action)),
        child: content,
      ),
    };
  }

  Color get _primaryOverlayBase => const Color(0xFFFFFFFF);

  WidgetStateProperty<Color?> _overlay(Color base) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return base.withValues(alpha: 0.15);
        }
        if (states.contains(WidgetState.hovered)) {
          return base.withValues(alpha: 0.08);
        }
        return null;
      });

  Color _labelColor(JColors c) => switch (variant) {
    JButtonVariant.primary => c.onAction,
    JButtonVariant.secondary => c.text1,
    JButtonVariant.text => c.action,
  };

  Color _loaderColor(JColors c) => switch (variant) {
    JButtonVariant.primary => c.onAction,
    JButtonVariant.secondary => c.text1,
    JButtonVariant.text => c.action,
  };
}
