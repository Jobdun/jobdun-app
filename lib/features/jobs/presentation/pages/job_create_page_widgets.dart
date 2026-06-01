part of 'job_create_page.dart';

// Form sub-widgets for JobCreatePage, split into a `part` so the page file
// stays under the 500 LOC ceiling. Each is private with a single caller in the
// page above. No behaviour change from the in-file originals.

// ── Trade picker ───────────────────────────────────────────────────────────────
//
// Wraps the existing chip-grid UI in a FormBuilderField so the trade selection
// participates in the form's validation lifecycle. Required — submission is
// blocked until a trade is picked.

class _TradePicker extends StatelessWidget {
  const _TradePicker({required this.trades});

  final List<String> trades;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return FormBuilderField<String>(
      name: 'trade',
      validator: FormBuilderValidators.required(errorText: 'Pick a trade.'),
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('TRADE REQUIRED'),
            Gap(10.h),
            Wrap(
              spacing: AppSpacing.sm.w,
              runSpacing: AppSpacing.sm.h,
              children: trades.map((t) {
                final active = field.value == t;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    field.didChange(active ? null : t);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 7.h,
                    ),
                    decoration: BoxDecoration(
                      color: active ? c.action : c.surface,
                      borderRadius: BorderRadius.circular(AppRadius.chip.r),
                      border: Border.all(
                        color: active ? c.action : c.border,
                        width: active ? 1.5 : 1.0,
                      ),
                    ),
                    child: Text(
                      t,
                      style: tt.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: active
                            ? Colors
                                  .white // intentional: white-on-action
                            : c.text2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (field.hasError) ...[
              Gap(6.h),
              Text(
                field.errorText!,
                style: tt.labelMedium!.copyWith(color: c.urgent),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Rate-type picker ───────────────────────────────────────────────────────────
//
// Three-segment selector (Hourly / Daily / Fixed). Default 'Hourly' is set on
// the FormBuilder's initialValue. Passes the new value up so the rate field's
// trailing label stays in sync.

class _RateTypePicker extends StatelessWidget {
  const _RateTypePicker({required this.rateTypes, required this.onChanged});

  final List<String> rateTypes;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return FormBuilderField<String>(
      name: 'rateType',
      builder: (field) {
        final selected = field.value ?? 'Hourly';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FieldLabel('RATE TYPE'),
            Gap(AppSpacing.sm.h),
            Row(
              children: rateTypes.map((rt) {
                final active = selected == rt;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      field.didChange(rt);
                      onChanged(rt);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: EdgeInsets.only(
                        right: rt != rateTypes.last ? AppSpacing.sm.w : 0,
                      ),
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      decoration: BoxDecoration(
                        color: active ? c.action : c.surface,
                        borderRadius: BorderRadius.circular(AppRadius.chip.r),
                        border: Border.all(color: active ? c.action : c.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        rt,
                        style: tt.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: active
                              ? Colors
                                    .white // intentional: white-on-action
                              : c.text2,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

// ── Urgent toggle ──────────────────────────────────────────────────────────────
//
// Wraps JSwitch in a FormBuilderField<bool> so the boolean ships out via
// formState.value['urgent']. Initial value comes from the form's initialValue
// block so the off state is explicit.

class _UrgentToggle extends StatelessWidget {
  const _UrgentToggle();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return FormBuilderField<bool>(
      name: 'urgent',
      builder: (field) {
        final isUrgent = field.value ?? false;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w,
            vertical: 14.h,
          ),
          decoration: BoxDecoration(
            color: isUrgent ? c.actionBg : c.surface,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            border: Border.all(color: isUrgent ? c.action : c.border),
          ),
          child: Row(
            children: [
              Icon(
                AppIcons.lightning,
                size: AppIconSize.md.r,
                color: isUrgent ? c.action : c.text3,
              ),
              Gap(12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mark as urgent',
                      style: tt.bodyLarge!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isUrgent ? c.action : c.text1,
                      ),
                    ),
                    Gap(2.h),
                    Text(
                      'Shown to more tradies, listed at the top',
                      style: tt.labelMedium!.copyWith(color: c.text3),
                    ),
                  ],
                ),
              ),
              JSwitch(
                value: isUrgent,
                onChanged: (v) {
                  HapticFeedback.lightImpact();
                  field.didChange(v);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
