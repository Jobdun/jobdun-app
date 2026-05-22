import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/bottom_action_bar.dart';
import '../../../../core/design/widgets/field_label.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_switch.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
import '../widgets/job_location_field.dart';

class JobCreatePage extends StatefulWidget {
  const JobCreatePage({super.key});

  @override
  State<JobCreatePage> createState() => _JobCreatePageState();
}

class _JobCreatePageState extends State<JobCreatePage> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isPosting = false;

  // Mirrors the active rate type into local state so the rate field's
  // trailing label ("/hr" vs "/day" vs "flat") can react without rebuilding
  // the whole form via the FormBuilder controller every keystroke.
  String _rateTypeForSuffix = 'Hourly';

  static const _trades = [
    'Electrician',
    'Plumber',
    'Carpenter',
    'Concreter',
    'Painter',
    'Roofer',
    'Welder',
    'Labourer',
  ];

  static const _rateTypes = ['Hourly', 'Daily', 'Fixed'];

  Future<void> _post(BuildContext context, JColors c) async {
    final tt = Theme.of(context).textTheme;
    final formState = _formKey.currentState;
    if (formState == null || !formState.saveAndValidate()) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _isPosting = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    // Placeholder for the real create-job API call. Values are read off
    // formState.value so the rest of the chain stays type-safe.
    // ignore: unused_local_variable
    final values = formState.value;
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _isPosting = false);
    router.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              AppIcons.successCircle,
              size: 18.r,
              color: Colors.white, // intentional: white-on-success
            ),
            Gap(10.w),
            Text(
              'Job posted successfully!',
              style: tt.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white, // intentional: white-on-success
              ),
            ),
          ],
        ),
        backgroundColor: c.verified,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: FormBuilder(
          key: _formKey,
          initialValue: const {'rateType': 'Hourly', 'urgent': false},
          child: Column(
            children: [
              // ── App bar
              Container(
                color: c.card,
                padding: EdgeInsets.fromLTRB(4.w, AppSpacing.sm.h, 20.w, 12.h),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(
                        AppIcons.closeCircle,
                        size: 22.r,
                        color: c.text1,
                      ),
                    ),
                    const Expanded(
                      child: PageHeader(
                        eyebrow: 'NEW LISTING',
                        title: 'Post a Job',
                        size: PageHeaderSize.sub,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.border),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20.w,
                    20.h,
                    20.w,
                    AppSpacing.lg.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      JTextField(
                        name: 'title',
                        label: 'JOB TITLE',
                        hint:
                            'e.g. Install 3-phase switchboard at commercial site',
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

                      _TradePicker(trades: _trades),
                      Gap(20.h),

                      const JobLocationField(),
                      Gap(4.h),

                      _RateTypePicker(
                        rateTypes: _rateTypes,
                        onChanged: (rt) =>
                            setState(() => _rateTypeForSuffix = rt),
                      ),
                      Gap(10.h),
                      JTextField(
                        name: 'rate',
                        label: 'RATE',
                        prefixText: '\$ ',
                        hint: '85',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        suffixIcon: Padding(
                          padding: EdgeInsets.only(right: 12.w),
                          child: Text(
                            _rateTypeForSuffix == 'Hourly'
                                ? '/hr'
                                : _rateTypeForSuffix == 'Daily'
                                ? '/day'
                                : 'flat',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium!.copyWith(color: c.text3),
                          ),
                        ),
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(
                            errorText: 'Rate is required.',
                          ),
                          FormBuilderValidators.integer(
                            errorText: 'Whole dollars only.',
                          ),
                          FormBuilderValidators.min(
                            1,
                            errorText: 'Must be at least \$1.',
                          ),
                        ]),
                      ),

                      JTextField(
                        name: 'description',
                        label: 'DESCRIPTION',
                        hint:
                            'Describe the scope of work, site conditions, tools required…',
                        textCapitalization: TextCapitalization.sentences,
                        maxLength: 1000,
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

                      const _UrgentToggle(),
                    ],
                  ),
                ),
              ),

              BottomActionBar(
                primary: JButton(
                  label: _isPosting ? 'POSTING...' : 'POST JOB',
                  icon: AppIcons.send,
                  isLoading: _isPosting,
                  onPressed: _isPosting ? null : () => _post(context, c),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
                size: 18.r,
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
