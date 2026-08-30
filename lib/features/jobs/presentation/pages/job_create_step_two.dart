part of 'job_create_page.dart';

/// Post a Job, step 2 of 2 — Figma node `134:13313`.
///
/// How the job is paid: the Set Price / Request Quotes segmented control, the
/// unit it is priced in, and the amount. Choosing Request Quotes hides the
/// amount field — tradies name their own figure on apply, and `_buildJob`
/// writes `budgetAmount: null` to satisfy the
/// `jobs_budget_amount_when_set` CHECK.
class _StepTwo extends StatelessWidget {
  const _StepTwo({
    required this.pricingMode,
    required this.pricingUnit,
    required this.rateHint,
    required this.onModeChanged,
    required this.onUnitChanged,
  });

  final PricingType pricingMode;
  final PricingUnit pricingUnit;
  final String? rateHint;
  final ValueChanged<PricingType> onModeChanged;
  final ValueChanged<PricingUnit> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, AppSpacing.lg.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PricingModePicker(onChanged: onModeChanged),
          Gap(24.h),
          Text(
            'Price per:',
            style: tt.bodyMedium!.copyWith(height: 1.0, color: c.text1),
          ),
          Gap(12.h),
          _PricingUnitPicker(onChanged: onUnitChanged),
          Gap(16.h),
          if (pricingMode == PricingType.builderSet)
            JTextField(
              name: 'rate',
              // Persistent "$" via the always-visible prefix slot, mirroring
              // the always-on unit suffix.
              prefix: Padding(
                padding: EdgeInsets.only(left: 16.w, right: 6.w),
                child: Text(
                  '\$',
                  style: tt.bodyLarge!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              hint: '0',
              helperText: rateHint,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              suffixIcon: Padding(
                padding: EdgeInsets.only(right: 12.w),
                child: Text(
                  pricingUnit.suffix.isEmpty ? 'total' : pricingUnit.suffix,
                  style: tt.bodyMedium!.copyWith(color: c.text3),
                ),
              ),
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(errorText: 'Rate is required.'),
                FormBuilderValidators.integer(errorText: 'Whole dollars only.'),
                FormBuilderValidators.min(
                  1,
                  errorText: 'Must be at least \$1.',
                ),
              ]),
            )
          else
            const _QuoteModeNote(),
        ],
      ),
    );
  }
}
