part of 'job_create_page.dart';

/// Post a Job, step 1 of 2 — Figma node `134:13408`.
///
/// Urgency, then the four fields that describe the job: title, location,
/// description and the trade required. Pricing moved to [_StepTwo].
///
/// Every field keeps the name it had when this page was one long scroll, so
/// `_buildJob` and `_scrollToFirstError` read exactly the same map.
class _StepOne extends StatelessWidget {
  const _StepOne({required this.trades, required this.onTradeChanged});

  final List<String> trades;
  final ValueChanged<String?> onTradeChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, AppSpacing.lg.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _UrgentToggle(),
          Gap(24.h),
          JTextField(
            name: 'title',
            label: 'Job Title',
            hint: 'e.g. Install a 3 phase switchboard',
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(
                errorText: 'Job title is required.',
              ),
              FormBuilderValidators.minLength(
                8,
                errorText: 'Use at least 8 characters.',
              ),
            ]),
          ),
          Gap(16.h),
          const JobLocationField(),
          Gap(16.h),
          JTextField(
            name: 'description',
            label: 'Description',
            hint:
                'Describe the scope of work, site conditions, tools required…',
            textCapitalization: TextCapitalization.sentences,
            maxLength: 1000,
            maxLines: 5,
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(
                errorText: 'A short description helps tradies.',
              ),
              FormBuilderValidators.minLength(
                20,
                errorText: 'Use at least 20 characters.',
              ),
            ]),
          ),
          Gap(16.h),
          _TradePicker(trades: trades, onChanged: onTradeChanged),
        ],
      ),
    );
  }
}
