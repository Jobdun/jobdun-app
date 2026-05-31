part of 'profile_edit_page.dart';

// Leaf widgets + the ABN-verified predicate for the profile-edit page, split
// into a `part` so `profile_edit_page.dart` stays under the file-size budget.
// Private, single-use, co-located with the page state. No behaviour change.

/// Persistent red bar above the BottomActionBar surfacing the last save
/// failure. Snackbars auto-dismiss after ~4 s and the user can easily miss
/// them; the banner stays until the user re-attempts save or hits dismiss.
class _SaveErrorBanner extends StatelessWidget {
  const _SaveErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      color: c.urgentBg,
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 8.w, 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.urgent, size: AppIconSize.inline.r, color: c.urgent),
          Gap(10.w),
          Expanded(
            child: Text(
              message,
              style: tt.bodySmall!.copyWith(
                color: c.urgentTx,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            onPressed: onDismiss,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              AppIcons.close,
              size: AppIconSize.inline.r,
              color: c.urgentTx,
            ),
          ),
        ],
      ),
    );
  }
}

// Tappable input-shaped tile that mirrors JTextField's chrome and opens the
// TradeCategoryPicker. Resolves display label from the cached categories list;
// falls back to the slug if the row isn't in the live list (renamed category).
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

// Two-up: label + helper text on the left, JSwitch on the right. The
// helper line changes wording when the toggle flips so the affordance and
// its consequence sit next to each other.
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

// Inline status row used in the VERIFICATION section. Done = check mark in
// the verified accent; not-done = small uppercase CTA that pushes the
// relevant fix-it screen.
class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.done,
    required this.ctaLabel,
    required this.onCta,
  });

  final IconData icon;
  final String label;
  final bool done;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.input.r),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppIconSize.md.r,
            color: done ? c.verified : c.text3,
          ),
          Gap(12.w),
          Expanded(
            child: Text(label, style: tt.bodyMedium!.copyWith(color: c.text1)),
          ),
          if (done)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.successCircle,
                  size: AppIconSize.inline.r,
                  color: c.verified,
                ),
                Gap(6.w),
                Text(
                  'VERIFIED',
                  style: tt.labelSmall!.copyWith(
                    color: c.verified,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            )
          else
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCta,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                child: Text(
                  ctaLabel,
                  style: tt.labelSmall!.copyWith(
                    color: c.action,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// True when the builder profile carries an ABN that was mirrored in from a
/// successful verify-abn run — used to lock Company Name + ABN inputs.
/// We treat `bp.abn != null` as proof of verification because the only path
/// that writes to that column is the Edge Function's post-ABR mirror.
bool _isAbnVerified(BuilderProfile? bp) =>
    bp?.abn != null && bp!.abn!.trim().isNotEmpty;

/// FormBuilder text input that switches into a read-only "verified, locked"
/// state when the corresponding row already carries an ABR-confirmed value.
/// Renders the same JTextField shell either way so layout stays stable —
/// the lock state surfaces via a small "✓ Verified" chip next to the label,
/// the disabled input itself, and a "Contact support to change" hint line.
class _VerifiedLockedField extends StatelessWidget {
  const _VerifiedLockedField({
    required this.label,
    required this.fieldName,
    required this.initialValue,
    required this.hint,
    required this.locked,
    this.keyboardType,
    this.requiredField = false,
  });

  final String label;
  final String fieldName;
  final String? initialValue;
  final String hint;
  final bool locked;
  final TextInputType? keyboardType;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            FieldLabel(label),
            if (locked) ...[
              Gap(8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: c.verifiedBg,
                  borderRadius: BorderRadius.circular(4.r),
                  border: Border.all(color: c.verified.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.verified,
                      size: AppIconSize.micro.r,
                      color: c.verified,
                    ),
                    Gap(4.w),
                    Text(
                      'VERIFIED',
                      style: tt.labelSmall!.copyWith(
                        fontSize: 9.sp,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: c.verified,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        Gap(AppSpacing.sm.h),
        JTextField(
          name: fieldName,
          hint: hint,
          initialValue: initialValue,
          enabled: !locked,
          keyboardType: keyboardType,
          validator: requiredField
              ? FormBuilderValidators.required(errorText: '$label is required.')
              : null,
        ),
        if (locked) ...[
          Gap(4.h),
          Text(
            'Locked after ABR verification. Contact support to change.',
            style: tt.bodySmall!.copyWith(
              fontSize: 11.sp,
              color: c.text3,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}
