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
import '../../../../../core/widgets/inputs/j_text_field.dart';
import '../../../domain/entities/apprenticeship_stage.dart';
import '../../../domain/entities/profile_patches.dart';
import '../../providers/profile_provider.dart';
import '../../providers/trade_categories_provider.dart';
import '../trade_category_picker.dart';
import 'apprenticeship_fields.dart';
import 'availability_fields.dart';
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
  bool _isApprentice = false;
  ApprenticeshipStage? _stage;

  @override
  void initState() {
    super.initState();
    final tp = ref.read(profileControllerProvider).tradeProfile;
    if (tp != null && tp.primaryTrade.isNotEmpty) _tradeSlug = tp.primaryTrade;
    _tradeOther = tp?.tradeOther;
    _isApprentice = tp?.isApprentice ?? false;
    _stage = tp?.apprenticeshipStage;
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
    final apprentice = apprenticeshipPatch(
      isApprentice: _isApprentice,
      stage: _stage,
    );
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .savePatches(
          trade: TradeProfilePatch(
            primaryTrade: Some(_tradeSlug!),
            tradeOther: Some(_tradeSlug == 'other' ? _tradeOther : null),
            isAvailable: Some(isAvailable),
            // Available now ⇒ no "free from" date; otherwise keep the choice.
            availableFrom: Some(
              isAvailable ? null : values['available_from'] as DateTime?,
            ),
            isApprentice: apprentice.isApprentice,
            apprenticeshipStage: apprentice.apprenticeshipStage,
            // An apprentice is on award rates, so years-of-experience is not
            // asked for and must be cleared rather than left stale.
            yearsExperience: _isApprentice
                ? const Some(null)
                : Some(_parseIntOrNull(values['years_experience'])),
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
            ApprenticeshipFields(
              isApprentice: _isApprentice,
              stage: _stage,
              onApprenticeChanged: (v) => setState(() {
                _isApprentice = v;
                _dirty = true;
              }),
              onStageChanged: (s) => setState(() {
                _stage = s;
                _dirty = true;
              }),
            ),
            // A first-year has no years of experience to report. Asking is
            // noise, and a blank field reads as an incomplete profile.
            if (!_isApprentice) ...[
              Gap(AppSpacing.md.h),
              const FieldLabel('YEARS OF EXPERIENCE'),
              Gap(AppSpacing.sm.h),
              JTextField(
                name: 'years_experience',
                hint: 'e.g. 8',
                initialValue: tp?.yearsExperience?.toString(),
                keyboardType: TextInputType.number,
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.integer(
                    errorText: 'Whole numbers only.',
                  ),
                  FormBuilderValidators.min(0, errorText: 'Must be 0 or more.'),
                  FormBuilderValidators.max(
                    60,
                    errorText: 'Must be 60 or fewer.',
                  ),
                ]),
              ),
            ],
            Gap(AppSpacing.md.h),
            const FieldLabel('AVAILABILITY'),
            Gap(AppSpacing.sm.h),
            AvailabilityFields(tp: tp),
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
