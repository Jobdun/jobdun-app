import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../../core/design/colors.dart';
import '../../../domain/entities/site_ticket.dart';

/// One selectable ticket in the tickets sheet.
///
/// A 48dp row rather than a dropdown entry: labels like "EWP High Risk Work
/// Licence (WP, boom 11m+)" truncate in a dropdown, the verified state has
/// nowhere to live, and the hit target collapses to about 24dp. Same
/// tick-the-boxes mental model, correct control for a phone on a worksite.
///
/// A verified row is LOCKED ON. Its tick came from a document a human
/// reviewed, so the user cannot untick it here — unticking would claim they no
/// longer hold a credential the platform has evidence for. Tapping explains
/// that instead of silently swallowing the gesture.
class TicketRow extends StatelessWidget {
  const TicketRow({
    super.key,
    required this.ticket,
    required this.isSelected,
    required this.isVerified,
    required this.onChanged,
    this.onLockedTap,
  });

  final SiteTicket ticket;
  final bool isSelected;
  final bool isVerified;
  final ValueChanged<bool> onChanged;

  /// Called instead of [onChanged] when the row is verified and therefore
  /// locked. Lets the sheet surface a reason rather than doing nothing.
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    // Verified implies selected: the credential exists whatever the local
    // checkbox state says.
    final ticked = isVerified || isSelected;
    final detail = ticket.detail;

    return Semantics(
      button: true,
      checked: ticked,
      enabled: !isVerified,
      label:
          '${ticket.shortName}, '
          '${isVerified ? 'verified' : 'self-declared'}, '
          '${ticked ? 'selected' : 'not selected'}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isVerified ? onLockedTap : () => onChanged(!isSelected),
          child: ConstrainedBox(
            // minHeight, never a fixed height: the row has to grow when the
            // OS text scaler is turned up (clamped 0.9-1.3 app-wide).
            constraints: BoxConstraints(minHeight: 48.h),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _TickBox(ticked: ticked, locked: isVerified),
                  Gap(AppSpacing.md.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ticket.shortName,
                          style: tt.titleSmall!.copyWith(color: c.text1),
                        ),
                        if (detail != null) ...[
                          Gap(2.h),
                          Text(
                            detail,
                            style: tt.bodySmall!.copyWith(color: c.text2),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isVerified) ...[Gap(AppSpacing.sm.w), _VerifiedTag()],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sharp square tick box. Deliberately not Material's rounded [Checkbox]: a
/// container corner is structural in this design system and stays tight
/// (AppRadius.badge), while controls that should read as pressable round.
class _TickBox extends StatelessWidget {
  const _TickBox({required this.ticked, required this.locked});

  final bool ticked;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 22.r,
      height: 22.r,
      decoration: BoxDecoration(
        color: ticked ? c.action : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.badge.r),
        border: Border.all(color: ticked ? c.action : c.borderStrong, width: 2),
      ),
      child: ticked
          // Dark-on-orange. White on this orange is 3.33:1, under the text bar.
          ? Icon(AppIcons.check, size: 14.r, color: c.onAction)
          : null,
    );
  }
}

class _VerifiedTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: c.verifiedBg,
        borderRadius: BorderRadius.circular(AppRadius.badge.r),
      ),
      child: Text(
        'VERIFIED',
        style: tt.labelSmall!.copyWith(color: c.verifiedTx),
      ),
    );
  }
}

/// Section header above each ticket group.
///
/// Uses c.text3, which is legal here because the sheet ground is c.surface.
/// It would NOT be legal on c.surfaceRaised (3.54:1 there).
class TicketGroupHeader extends StatelessWidget {
  const TicketGroupHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.md.h, bottom: 4.h),
      child: Text(
        label.toUpperCase(),
        style: tt.labelSmall!.copyWith(color: c.text3),
      ),
    );
  }
}
