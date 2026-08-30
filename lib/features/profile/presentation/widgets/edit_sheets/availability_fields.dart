import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/design/widgets/field_label.dart';
import '../../../../../core/design/widgets/j_switch.dart';
import '../../../domain/entities/trade_profile.dart';

/// Availability controls threaded through FormBuilder so _save reads
/// `is_available` / `available_from` off the form values. "Open for work"
/// off reveals an optional "free from" date.
class AvailabilityFields extends StatelessWidget {
  const AvailabilityFields({super.key, required this.tp});

  final TradeProfile? tp;

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<bool>(
      name: 'is_available',
      initialValue: tp?.isAvailable ?? true,
      builder: (field) {
        final open = field.value ?? true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AvailabilityToggleRow(value: open, onChanged: field.didChange),
            if (!open) ...[
              Gap(AppSpacing.md.h),
              const FieldLabel('AVAILABLE FROM'),
              Gap(AppSpacing.sm.h),
              _AvailableFromField(initial: tp?.availableFrom),
            ],
          ],
        );
      },
    );
  }
}

// "Open for work" toggle. Off ⇒ the trade is hidden from searches until their
// available-from date passes (search treats isAvailable OR from<=today).
class _AvailabilityToggleRow extends StatelessWidget {
  const _AvailabilityToggleRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
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
                  'Open for work',
                  style: tt.bodyMedium!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Gap(2.h),
                Text(
                  value
                      ? "Show up in builders' searches."
                      : 'Hidden from searches until your start date.',
                  style: tt.bodySmall!.copyWith(color: c.text3),
                ),
              ],
            ),
          ),
          Gap(10.w),
          JSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// Optional "free from" date tile, backed by a FormBuilderField so _save reads
// `available_from` straight off the form values.
class _AvailableFromField extends StatelessWidget {
  const _AvailableFromField({required this.initial});

  final DateTime? initial;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static String _fmt(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return FormBuilderField<DateTime>(
      name: 'available_from',
      initialValue: initial,
      builder: (field) {
        final v = field.value;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: v ?? now,
              firstDate: now,
              lastDate: now.add(const Duration(days: 365)),
            );
            if (picked != null) field.didChange(picked);
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadius.input.r),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Icon(
                  AppIcons.calendar,
                  size: AppIconSize.inline.r,
                  color: c.text3,
                ),
                Gap(10.w),
                Expanded(
                  child: Text(
                    v != null ? _fmt(v) : "Leave blank if you're ready now.",
                    style: tt.bodyMedium!.copyWith(
                      color: v != null ? c.text1 : c.text3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
