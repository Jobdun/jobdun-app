import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/field_label.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../providers/scheduling_provider.dart';

/// Shown on the applicant screen once a trade is hired (#15): the builder picks
/// a start date, which creates a booking both parties then see on the schedule.
class ScheduleBuilderCard extends ConsumerStatefulWidget {
  const ScheduleBuilderCard({
    super.key,
    required this.jobId,
    required this.tradeId,
  });

  final String jobId;
  final String tradeId;

  @override
  ConsumerState<ScheduleBuilderCard> createState() =>
      _ScheduleBuilderCardState();
}

class _ScheduleBuilderCardState extends ConsumerState<ScheduleBuilderCard> {
  bool _busy = false;

  Future<void> _pick() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(bookingActionsProvider)
        .create(
          jobId: widget.jobId,
          tradeId: widget.tradeId,
          scheduledDate: picked,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Start date scheduled.' : "Couldn't schedule. Try again.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('SCHEDULE'),
        Gap(AppSpacing.sm.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppSpacing.md.w),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set a start date — it lands on both your schedules.',
                style: tt.bodyMedium!.copyWith(color: c.text2),
              ),
              Gap(AppSpacing.md.h),
              SizedBox(
                width: double.infinity,
                child: JButton(
                  label: 'SET START DATE',
                  size: JButtonSize.compact,
                  isLoading: _busy,
                  onPressed: _busy ? null : _pick,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
