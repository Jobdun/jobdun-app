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
    required this.isApprenticeship,
    required this.pricingMode,
    required this.pricingUnit,
    required this.rateHint,
    required this.onModeChanged,
    required this.onUnitChanged,
  });

  final bool isApprenticeship;
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
          if (isApprenticeship)
            Text('Hourly pay', style: tt.titleLarge!.copyWith(color: c.text1))
          else
            _PricingModePicker(onChanged: onModeChanged),
          if (!isApprenticeship) Gap(24.h),
          if (!isApprenticeship)
            Text(
              'Price per:',
              style: tt.bodyMedium!.copyWith(height: 1.0, color: c.text1),
            ),
          if (!isApprenticeship) Gap(12.h),
          if (!isApprenticeship) _PricingUnitPicker(onChanged: onUnitChanged),
          Gap(16.h),
          if (isApprenticeship || pricingMode == PricingType.builderSet)
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
              helperText: isApprenticeship
                  ? 'Enter the hourly pay you offer. Include training and hours in the description.'
                  : rateHint,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) =>
                      RegExp(r'^\d*\.?\d{0,2}$').hasMatch(newValue.text)
                      ? newValue
                      : oldValue,
                ),
              ],
              suffixIcon: Padding(
                padding: EdgeInsets.only(right: 12.w),
                child: Text(
                  isApprenticeship
                      ? '/hr'
                      : pricingUnit.suffix.isEmpty
                      ? 'total'
                      : pricingUnit.suffix,
                  style: tt.bodyMedium!.copyWith(color: c.text3),
                ),
              ),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                if (amount == null || !amount.isFinite || amount <= 0) {
                  return 'Enter a positive amount.';
                }
                return null;
              },
            )
          else
            const _QuoteModeNote(),
        ],
      ),
    );
  }
}
