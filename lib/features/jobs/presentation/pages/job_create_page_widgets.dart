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
  const _TradePicker({required this.trades, required this.onChanged});

  final List<String> trades;

  /// Mirrors the picked trade (or null on deselect) up to the page so the rate
  /// field can show a trade-aware hourly guide.
  final ValueChanged<String?> onChanged;

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
            Text(
              'Trade Required',
              style: tt.bodyMedium!.copyWith(height: 1.0, color: c.text1),
            ),
            Gap(12.h),
            Wrap(
              spacing: 8.w,
              children: trades.map((t) {
                final active = field.value == t;
                return JSelectChip(
                  label: t,
                  selected: active,
                  onTap: () {
                    final next = active ? null : t;
                    field.didChange(next);
                    onChanged(next);
                  },
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

// ── Pricing mode picker ────────────────────────────────────────────────────────
//
// Two-segment selector: Set price (builder names a rate) vs Request quotes
// (tradies send their own). Default builder_set via the FormBuilder
// initialValue. Passes the mode up so the page shows/hides the amount field.

class _PricingModePicker extends StatelessWidget {
  const _PricingModePicker({required this.onChanged});

  final ValueChanged<PricingType> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return FormBuilderField<PricingType>(
      name: 'pricingMode',
      builder: (field) {
        final selected = field.value ?? PricingType.builderSet;
        // Figma node 134:13316 — one rounded track, 6dp inset, the active
        // segment filled orange. Replaces the old pair of separate chips.
        return Container(
          padding: EdgeInsets.all(6.r),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.btn.r),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: PricingType.values.map((mode) {
              return Expanded(
                child: _PricingModeSegment(
                  label: mode.label,
                  active: selected == mode,
                  onTap: () {
                    field.didChange(mode);
                    onChanged(mode);
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

/// One segment of [_PricingModePicker]. Single caller, directly above.
class _PricingModeSegment extends StatelessWidget {
  const _PricingModeSegment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: active,
      label: '$label, ${active ? "selected" : "not selected"}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.ease,
          height: 40.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? c.action : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.btn.r),
          ),
          child: Text(
            label,
            style: tt.titleMedium!.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.0,
              // The mock sets the active label white; `onAction` carries it at
              // 5.26:1 instead (white is 3.34:1 on the orange).
              color: active ? c.onAction : c.text2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ── Pricing unit picker ────────────────────────────────────────────────────────
//
// Single-select chip grid for the unit a job is priced in (Per hour / Per m² /
// Per lineal metre / Per job). A Wrap, not an equal-width Row, so "Per lineal
// metre" isn't squeezed. Default hourly via the FormBuilder initialValue.

class _PricingUnitPicker extends StatelessWidget {
  const _PricingUnitPicker({required this.onChanged});

  final ValueChanged<PricingUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    return FormBuilderField<PricingUnit>(
      name: 'pricingUnit',
      builder: (field) {
        final selected = field.value ?? PricingUnit.hourly;
        return Wrap(
          spacing: 8.w,
          children: PricingUnit.values.map((unit) {
            return JSelectChip(
              label: unit.label,
              selected: selected == unit,
              onTap: () {
                field.didChange(unit);
                onChanged(unit);
              },
            );
          }).toList(),
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
        // Figma node 134:13415 — a plain bordered card, not a tinted one. The
        // switch carries the state; tinting the card as well double-signalled
        // it and made the unselected state read as disabled.
        return Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
            border: Border.all(color: isUrgent ? c.action : c.border),
          ),
          child: Row(
            children: [
              Icon(
                AppIcons.lightning,
                size: 24.r,
                color: isUrgent ? c.actionInk : c.text2,
              ),
              Gap(8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mark as Urgent',
                      style: tt.titleMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        color: c.text1,
                      ),
                    ),
                    Gap(4.h),
                    Text(
                      'Shown to more tradies, listed at the top.',
                      style: tt.bodyMedium!.copyWith(
                        height: 1.4,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
              ),
              Gap(8.w),
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

// Soft-gate sheet shown when an unverified builder taps POST JOB. Routes to the
// ~15s ABN wizard; the create form stays intact behind it.
class _VerifyGateSheet extends StatelessWidget {
  const _VerifyGateSheet();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card.r),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg.w,
        AppSpacing.md.h,
        AppSpacing.lg.w,
        AppSpacing.lg.h,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Gap(AppSpacing.lg.h),
            Container(
              width: 56.r,
              height: 56.r,
              decoration: BoxDecoration(
                color: c.actionBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.shield,
                size: AppIconSize.feature.r,
                color: c.action,
              ),
            ),
            Gap(AppSpacing.md.h),
            Text(
              'VERIFY YOUR BUSINESS',
              style: tt.headlineSmall!.copyWith(color: c.text1),
              textAlign: TextAlign.center,
            ),
            Gap(AppSpacing.sm.h),
            Text(
              'Verified businesses can post jobs and get more applicants. '
              "It's a quick ABN check — about 15 seconds.",
              style: tt.bodyMedium!.copyWith(color: c.text2),
              textAlign: TextAlign.center,
            ),
            Gap(AppSpacing.lg.h),
            JButton(
              label: 'VERIFY NOW',
              icon: AppIcons.shield,
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/verification/wizard');
              },
            ),
            Gap(AppSpacing.sm.h),
            JButton(
              label: 'NOT NOW',
              variant: JButtonVariant.text,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

// Shown in place of the rate field when the builder chose "request quotes":
// tradies submit their own quote on apply. Flat surface card (MASTER: no shadow).
class _QuoteModeNote extends StatelessWidget {
  const _QuoteModeNote();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: EdgeInsets.all(AppSpacing.md.r),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(AppIcons.quote, size: AppIconSize.md.r, color: c.text3),
          Gap(10.w),
          Expanded(
            child: Text(
              'Tradies send their quotes when they apply. '
              "You'll see each quote on the Applicants screen.",
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: c.text2, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
