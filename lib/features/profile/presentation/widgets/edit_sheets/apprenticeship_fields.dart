import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fpdart/fpdart.dart' show Some;
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/design/widgets/field_label.dart';
import '../../../../../core/design/widgets/j_switch.dart';
import '../../../domain/entities/apprenticeship_stage.dart';
import '../../../domain/entities/profile_patches.dart';

/// Builds the apprentice half of a trade patch.
///
/// Flipping the toggle OFF explicitly writes `Some(null)` for the stage. A
/// `None()` would leave the old value in the row, so a tradie who tried
/// apprentice mode and turned it back off would silently resurface "3rd year"
/// if they ever re-enabled it.
///
/// Pure and top-level so it is unit-testable without pumping a sheet.
TradeProfilePatch apprenticeshipPatch({
  required bool isApprentice,
  required ApprenticeshipStage? stage,
}) => TradeProfilePatch(
  isApprentice: Some(isApprentice),
  apprenticeshipStage: Some(isApprentice ? stage : null),
);

/// "I'm looking for an apprenticeship" toggle plus the stage picker it
/// reveals. Lives in its own file because trade_details_sheet.dart was already
/// at the 400-line target before this was added.
class ApprenticeshipFields extends StatelessWidget {
  const ApprenticeshipFields({
    super.key,
    required this.isApprentice,
    required this.stage,
    required this.onApprenticeChanged,
    required this.onStageChanged,
  });

  final bool isApprentice;
  final ApprenticeshipStage? stage;
  final ValueChanged<bool> onApprenticeChanged;
  final ValueChanged<ApprenticeshipStage> onStageChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    // The reveal is state, not decoration, so it animates — but never against
    // a user who has asked the OS to stop animations.
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.input.r),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "I'm looking for an apprenticeship",
                      style: tt.bodyMedium!.copyWith(
                        color: c.text1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Gap(2.h),
                    Text(
                      isApprentice
                          ? 'Builders see your stage and tickets instead of rates.'
                          : 'Turn this on if you want to be put on.',
                      style: tt.bodySmall!.copyWith(color: c.text3),
                    ),
                  ],
                ),
              ),
              Gap(10.w),
              JSwitch(value: isApprentice, onChanged: onApprenticeChanged),
            ],
          ),
        ),
        AnimatedSize(
          duration: Duration(milliseconds: reduceMotion ? 0 : 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: isApprentice
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Gap(AppSpacing.md.h),
                    const FieldLabel('STAGE'),
                    Gap(AppSpacing.sm.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        for (final s in ApprenticeshipStage.values)
                          StagePill(
                            stage: s,
                            selected: stage == s,
                            onTap: () => onStageChanged(s),
                          ),
                      ],
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// One selectable apprenticeship-stage pill.
///
/// 48dp minimum height so it clears the touch-target floor — a Material chip's
/// default 32dp does not.
class StagePill extends StatelessWidget {
  const StagePill({
    super.key,
    required this.stage,
    required this.selected,
    required this.onTap,
  });

  final ApprenticeshipStage stage;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: stage.label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.chip.r),
          child: Container(
            // 48 unscaled, NOT 48.h. The touch-target floor is an absolute
            // WCAG 2.5.5 minimum in logical pixels; scaling it by screen
            // height shrinks it below the floor on short devices. Matches
            // AppTheme's `const Size(48, 48)`.
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            decoration: BoxDecoration(
              // Selected carries dark-on-orange (onAction). White on this
              // orange is 3.33:1, under the 4.5 text bar.
              color: selected ? c.action : c.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.chip.r),
            ),
            child: Text(
              stage.label,
              style: tt.titleSmall!.copyWith(
                color: selected ? c.onAction : c.text1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
