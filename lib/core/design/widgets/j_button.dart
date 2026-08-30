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
/// - [danger]    filled urgent-red, dark fg. Use for the dominant destructive
///               action (REJECT a verification, REVOKE, DELETE) — pairs beside
///               a [primary] / [secondary] cancel.
/// - [outline]   tinted brand fill, orange hairline, orange-ink label — the
///               Figma `bg/action-secondary` button ("Log out" on Settings,
///               node 134:9557). Reads as an affordance without competing with
///               a filled [primary].
/// - [dangerOutline] tinted red fill + red hairline and label. The destructive
///               half of a paired footer ("Delete job" beside "View
///               applicants") — quieter than [danger], which is for when
///               destruction is the screen's *dominant* action.
/// - [successOutline] tinted green fill + green hairline and label. The
///               *confirming* half of a triage pair ("Hire this tradie" on the
///               applicant card, Figma `JobDun-Screens` → Applicants, node
///               122:5136). Green because the action is a commitment, not the
///               screen's default next step — a filled orange CTA there would
///               out-shout the reject it sits above.
enum JButtonVariant {
  primary,
  secondary,
  text,
  danger,
  outline,
  dangerOutline,
  successOutline,
}

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
    JButtonSize.standard => 48.h,
    JButtonSize.compact => 40.h,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    // Figma `Typography/Label/L-BOLD` — Inter Bold 18 on a standard button,
    // stepping down for the compact in-row variant. Reads off titleMedium
    // (Inter) rather than labelLarge (Archivo): the mock sets button text in
    // the body family, and Archivo at 18 is too wide for a two-word label on
    // a 360dp screen.
    // A spinning button is never tappable: call sites that passed isLoading
    // but forgot to null onPressed shipped double-submits (double quotes,
    // double job posts — races audit, 2026-08-18).
    final effectiveOnPressed = isLoading ? null : onPressed;

    final labelStyle = tt.titleMedium!.copyWith(
      fontSize: size == JButtonSize.standard ? 18 : 15,
      fontWeight: FontWeight.w700,
      height: 1.0,
      color: _labelColor(c, enabled: effectiveOnPressed != null),
    );

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
        onPressed: effectiveOnPressed,
        style: FilledButton.styleFrom(
          backgroundColor: c.action,
          foregroundColor: c.onAction,
          // A flat grey, not a faded orange. Figma `bg/disabled` #E4E4E4 +
          // `text/tertiary` — which land exactly on c.border and c.text3.
          // The old translucent-orange read as "still the CTA, just dimmer";
          // this reads as "not yet available", which is the actual state when
          // the terms box is unticked.
          disabledBackgroundColor: c.border,
          disabledForegroundColor: c.text3,
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
        onPressed: effectiveOnPressed,
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
        onPressed: effectiveOnPressed,
        style: TextButton.styleFrom(
          foregroundColor: c.action,
          minimumSize: Size.fromHeight(
            size == JButtonSize.standard ? 44.h : 36.h,
          ),
        ).copyWith(overlayColor: _overlay(c.action)),
        child: content,
      ),
      JButtonVariant.danger => FilledButton(
        onPressed: effectiveOnPressed,
        style: FilledButton.styleFrom(
          backgroundColor: c.urgent,
          foregroundColor: c.onAction,
          disabledBackgroundColor: c.border,
          disabledForegroundColor: c.text3,
          minimumSize: Size.fromHeight(_minHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.btn.r),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ).copyWith(overlayColor: _overlay(_primaryOverlayBase)),
        child: content,
      ),
      // The mock draws both outline variants with a 1px hairline. `c.action`
      // and `c.urgentTx` are the border colours because the label sits ON the
      // page ground, not on a fill — so the ink token applies, not the fill
      // token (MASTER → "action is the FILL; actionInk is the orange INK").
      JButtonVariant.outline => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: OutlinedButton.styleFrom(
          // Figma `bg/action-secondary` — the tinted wash that makes the
          // hairline read as a button rather than a bare label.
          backgroundColor: c.actionBg,
          foregroundColor: c.actionInk,
          disabledForegroundColor: c.text3,
          side: BorderSide(color: c.action),
          minimumSize: Size.fromHeight(_minHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.btn.r),
          ),
        ).copyWith(overlayColor: _overlay(c.action)),
        child: content,
      ),
      JButtonVariant.dangerOutline => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: c.urgentBg,
          foregroundColor: c.urgentTx,
          disabledForegroundColor: c.text3,
          side: BorderSide(color: c.urgentTx),
          minimumSize: Size.fromHeight(_minHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.btn.r),
          ),
        ).copyWith(overlayColor: _overlay(c.urgent)),
        child: content,
      ),
      JButtonVariant.successOutline => OutlinedButton(
        onPressed: effectiveOnPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: c.verifiedBg,
          foregroundColor: c.verifiedTx,
          disabledForegroundColor: c.text3,
          side: BorderSide(color: c.verifiedTx),
          minimumSize: Size.fromHeight(_minHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.btn.r),
          ),
        ).copyWith(overlayColor: _overlay(c.verified)),
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

  /// Label colour. [enabled] is threaded through because [labelStyle] sets the
  /// `Text` colour directly, which wins over the button style's
  /// `disabledForegroundColor` — without this a disabled button rendered its
  /// label at full strength on the grey fill, so the only disabled signal was
  /// the background. Surfaced by the Figma job-posting flow, whose step-1
  /// "Next" sits disabled until the form validates.
  Color _labelColor(JColors c, {bool enabled = true}) {
    if (!enabled) return c.text3;
    return switch (variant) {
      JButtonVariant.primary => c.onAction,
      JButtonVariant.secondary => c.text1,
      JButtonVariant.text => c.action,
      JButtonVariant.danger => c.onAction,
      JButtonVariant.outline => c.actionInk,
      JButtonVariant.dangerOutline => c.urgentTx,
      JButtonVariant.successOutline => c.verifiedTx,
    };
  }

  Color _loaderColor(JColors c) => switch (variant) {
    JButtonVariant.primary => c.onAction,
    JButtonVariant.secondary => c.text1,
    JButtonVariant.text => c.action,
    JButtonVariant.danger => c.onAction,
    JButtonVariant.outline => c.actionInk,
    JButtonVariant.dangerOutline => c.urgentTx,
    JButtonVariant.successOutline => c.verifiedTx,
  };
}
