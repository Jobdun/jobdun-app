import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:fpdart/fpdart.dart' show Some;
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/design/widgets/field_label.dart';
import '../../../../../core/design/widgets/j_switch.dart';
import '../../../../../core/widgets/inputs/j_text_field.dart';
import '../../../domain/entities/profile_patches.dart';
import '../../../domain/entities/trade_profile.dart';
import '../../providers/profile_provider.dart';
import '../../providers/trade_categories_provider.dart';
import '../trade_category_picker.dart';
import 'edit_sheet_scaffold.dart';

/// Quick-edit sheet for trade identity + availability (tradies): trade picker,
/// years of experience, "open for work" toggle with optional free-from date.
/// Saves only those columns via TradeProfilePatch.
class TradeDetailsSheet extends ConsumerStatefulWidget {
  const TradeDetailsSheet({super.key});

  @override
  ConsumerState<TradeDetailsSheet> createState() => _TradeDetailsSheetState();
}

class _TradeDetailsSheetState extends ConsumerState<TradeDetailsSheet> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _dirty = false;
  bool _saving = false;
  String? _error;

  String? _tradeSlug;
  String? _tradeOther;
  bool _showTradeError = false;

  @override
  void initState() {
    super.initState();
    final tp = ref.read(profileControllerProvider).tradeProfile;
    if (tp != null && tp.primaryTrade.isNotEmpty) _tradeSlug = tp.primaryTrade;
    _tradeOther = tp?.tradeOther;
  }

  int? _parseIntOrNull(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  Future<void> _pickTrade() async {
    final selection = await showTradeCategoryPicker(
      context,
      initialSlug: _tradeSlug,
      initialOtherText: _tradeOther,
    );
    if (selection == null) return;
    setState(() {
      _tradeSlug = selection.slug;
      _tradeOther = selection.slug == 'other' ? selection.otherText : null;
      _showTradeError = false;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState?.saveAndValidate() ?? false;
    final tradeMissing = _tradeSlug == null || _tradeSlug!.isEmpty;
    if (tradeMissing) setState(() => _showTradeError = true);
    if (!formOk || tradeMissing) return;

    final values = _formKey.currentState!.value;
    final isAvailable = values['is_available'] as bool? ?? true;
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .savePatches(
          trade: TradeProfilePatch(
            primaryTrade: Some(_tradeSlug!),
            tradeOther: Some(_tradeSlug == 'other' ? _tradeOther : null),
            yearsExperience: Some(_parseIntOrNull(values['years_experience'])),
            isAvailable: Some(isAvailable),
            // Available now ⇒ no "free from" date; otherwise keep the choice.
            availableFrom: Some(
              isAvailable ? null : values['available_from'] as DateTime?,
            ),
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
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final tp = ref.read(profileControllerProvider).tradeProfile;
    return EditSheetScaffold(
      title: 'Trade & experience',
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
            const FieldLabel('TRADE'),
            Gap(AppSpacing.sm.h),
            _TradePickerTile(
              slug: _tradeSlug,
              otherText: _tradeOther,
              onTap: _pickTrade,
              hasError: _showTradeError && _tradeSlug == null,
            ),
            if (_showTradeError && _tradeSlug == null) ...[
              Gap(4.h),
              Text(
                'Pick a trade to continue.',
                style: tt.bodySmall!.copyWith(color: c.urgent),
              ),
            ],
            Gap(AppSpacing.md.h),
            const FieldLabel('YEARS OF EXPERIENCE'),
            Gap(AppSpacing.sm.h),
            JTextField(
              name: 'years_experience',
              hint: 'e.g. 8',
              initialValue: tp?.yearsExperience?.toString(),
              keyboardType: TextInputType.number,
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.integer(errorText: 'Whole numbers only.'),
                FormBuilderValidators.min(0, errorText: 'Must be 0 or more.'),
                FormBuilderValidators.max(
                  60,
                  errorText: 'Must be 60 or fewer.',
                ),
              ]),
            ),
            Gap(AppSpacing.md.h),
            const FieldLabel('AVAILABILITY'),
            Gap(AppSpacing.sm.h),
            _AvailabilityFields(tp: tp),
            Gap(AppSpacing.sm.h),
          ],
        ),
      ),
    );
  }
}

// The widgets below moved verbatim from the legacy edit form
// (profile_edit_widgets.dart / profile_edit_form_fields.dart) — single
// caller lives in this file now.

class _TradePickerTile extends ConsumerWidget {
  const _TradePickerTile({
    required this.slug,
    required this.otherText,
    required this.onTap,
    required this.hasError,
  });

  final String? slug;
  final String? otherText;
  final VoidCallback onTap;
  final bool hasError;

  String _label(AsyncValue<dynamic> async) {
    if (slug == null) return 'Pick your trade';
    if (slug == 'other') {
      return (otherText == null || otherText!.isEmpty)
          ? 'Other'
          : 'Other — $otherText';
    }
    return async.maybeWhen(
      data: (rows) {
        final list = rows as List<dynamic>;
        for (final r in list) {
          if (r.slug == slug) return r.displayName as String;
        }
        return slug!;
      },
      orElse: () => slug!,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final async = ref.watch(tradeCategoriesProvider);
    final hasValue = slug != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input.r),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.input.r),
            border: Border.all(color: hasError ? c.urgent : c.border),
          ),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _label(async),
                  style: tt.bodyLarge!.copyWith(
                    color: hasValue ? c.text1 : c.text3,
                  ),
                ),
              ),
              Icon(
                AppIcons.chevronDown,
                size: AppIconSize.inline.r,
                color: c.text3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Availability controls threaded through FormBuilder so _save reads
/// `is_available` / `available_from` off the form values. "Open for work"
/// off reveals an optional "free from" date.
class _AvailabilityFields extends StatelessWidget {
  const _AvailabilityFields({required this.tp});

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
