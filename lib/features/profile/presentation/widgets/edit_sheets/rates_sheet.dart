import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:fpdart/fpdart.dart' show Some;
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/design/widgets/field_label.dart';
import '../../../../../core/design/widgets/j_switch.dart';
import '../../../../../core/widgets/inputs/j_text_field.dart';
import '../../../domain/entities/profile_patches.dart';
import '../../providers/profile_provider.dart';
import 'edit_sheet_scaffold.dart';

/// Quick-edit sheet for hourly rates (tradies). Saves ONLY the three rate
/// columns via TradeProfilePatch — other profile fields are untouchable from
/// here by construction.
class RatesSheet extends ConsumerStatefulWidget {
  const RatesSheet({super.key});

  @override
  ConsumerState<RatesSheet> createState() => _RatesSheetState();
}

class _RatesSheetState extends ConsumerState<RatesSheet> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _dirty = false;
  bool _saving = false;
  String? _error;
  late bool _rateVisible;

  @override
  void initState() {
    super.initState();
    _rateVisible =
        ref.read(profileControllerProvider).tradeProfile?.hourlyRateVisible ??
        true;
  }

  double? _parse(Object? v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : double.tryParse(s);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .savePatches(
          trade: TradeProfilePatch(
            hourlyRateMin: Some(_parse(values['hourly_rate_min'])),
            hourlyRateMax: Some(_parse(values['hourly_rate_max'])),
            hourlyRateVisible: Some(_rateVisible),
          ),
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error =
            ref.read(profileControllerProvider).error ??
            "Couldn't save. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tp = ref.read(profileControllerProvider).tradeProfile;
    return EditSheetScaffold(
      title: 'Rates',
      isDirty: _dirty,
      isSaving: _saving,
      error: _error,
      onSave: _save,
      body: FormBuilder(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: () {
          if (!_dirty) setState(() => _dirty = true);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const FieldLabel('HOURLY RATE (AUD)'),
            Gap(AppSpacing.sm.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: JTextField(
                    name: 'hourly_rate_min',
                    hint: 'Min',
                    initialValue: tp?.hourlyRateMin?.toStringAsFixed(0),
                    keyboardType: TextInputType.number,
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.numeric(errorText: 'Numbers only.'),
                      FormBuilderValidators.min(
                        0,
                        errorText: 'Must be 0 or more.',
                      ),
                    ]),
                  ),
                ),
                Gap(10.w),
                Expanded(
                  child: JTextField(
                    name: 'hourly_rate_max',
                    hint: 'Max',
                    initialValue: tp?.hourlyRateMax?.toStringAsFixed(0),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final max = double.tryParse(v);
                      if (max == null) return 'Numbers only.';
                      if (max < 0) return 'Must be 0 or more.';
                      final minStr =
                          _formKey
                                  .currentState
                                  ?.fields['hourly_rate_min']
                                  ?.value
                              as String?;
                      final min = double.tryParse(minStr ?? '');
                      if (min != null && max < min) return 'Must be ≥ min.';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            Gap(AppSpacing.md.h),
            _RateVisibilityRow(
              value: _rateVisible,
              onChanged: (v) => setState(() {
                _rateVisible = v;
                _dirty = true;
              }),
            ),
            Gap(AppSpacing.sm.h),
          ],
        ),
      ),
    );
  }
}

// Moved verbatim from profile_edit_widgets.dart (single caller lives here now).
class _RateVisibilityRow extends StatelessWidget {
  const _RateVisibilityRow({required this.value, required this.onChanged});

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
                  'Show my rate to builders',
                  style: tt.bodyMedium!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Gap(2.h),
                Text(
                  value
                      ? 'Your hourly range appears on your applications.'
                      : 'Builders see "Rate on request" instead.',
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
