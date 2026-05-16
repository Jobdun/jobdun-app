import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/field_label.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/trade_categories_provider.dart';
import '../widgets/portfolio_strip.dart';
import '../widgets/trade_category_picker.dart';

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  final _formKey = GlobalKey<FormBuilderState>();

  // Trade picker is state-managed (not a FormBuilder field) — validated in
  // _save alongside the FormBuilder validators.
  String? _tradeSlug;
  String? _tradeOther;
  bool _showTradeError = false;

  @override
  void initState() {
    super.initState();
    final tp = ref.read(profileControllerProvider).tradeProfile;
    if (tp != null && tp.primaryTrade.isNotEmpty) {
      _tradeSlug = tp.primaryTrade;
    }
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
    });
  }

  Future<void> _save() async {
    final auth = ref.read(authControllerProvider);
    final role = auth.role;
    if (role == null) return;

    final formOk = _formKey.currentState?.saveAndValidate() ?? false;
    final isTrade = role == UserRole.trade;
    final tradeMissing = isTrade && (_tradeSlug == null || _tradeSlug!.isEmpty);
    if (tradeMissing) {
      setState(() => _showTradeError = true);
    }
    if (!formOk || tradeMissing) return;

    final values = _formKey.currentState!.value;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    final ok = await ref
        .read(profileControllerProvider.notifier)
        .saveProfile(
          role: role,
          displayName: values['display_name'] as String,
          suburb: values['suburb'] as String,
          auState: values['state'] as String?,
          about: values['about'] as String?,
          companyName: values['company_name'] as String?,
          abn: values['abn'] as String?,
          contactPhone: values['contact_phone'] as String?,
          fullName: values['full_name'] as String?,
          primaryTrade: _tradeSlug,
          tradeOther: _tradeOther,
        );

    if (!mounted) return;
    if (ok) {
      router.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Iconsax.tick_circle,
                size: 18.r,
                color: Colors.white, // intentional: white-on-success
              ),
              Gap(10.w),
              Text(
                'Profile updated.',
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
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            "Couldn't save changes. Try again.",
            style: tt.bodyMedium!.copyWith(
              color: Colors.white, // intentional: white-on-error
            ),
          ),
          backgroundColor: c.urgent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final authState = ref.watch(authControllerProvider);
    final isBuilder = authState.role == UserRole.builder;
    final profileState = ref.watch(profileControllerProvider);
    final profile = profileState.profile;
    final bp = profileState.builderProfile;
    final tp = profileState.tradeProfile;
    final isSaving = profileState.isLoading;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar
            Container(
              color: c.card,
              padding: EdgeInsets.fromLTRB(4.w, 8.h, 20.w, 12.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Iconsax.arrow_left, size: 22.r, color: c.text1),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EDIT PROFILE',
                          style: tt.labelSmall!.copyWith(
                            letterSpacing: 0.12 * 11,
                            color: c.text3,
                          ),
                        ),
                        Gap(2.h),
                        Text(
                          'Your details',
                          style: tt.headlineSmall!.copyWith(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w700,
                            color: c.text1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),

            Expanded(
              child: FormBuilder(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
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
                      if (isBuilder) ...[
                        const FieldLabel('COMPANY NAME'),
                        Gap(AppSpacing.sm.h),
                        _FormField(
                          name: 'company_name',
                          hint: 'e.g. Pinnacle Construct',
                          initialValue: bp?.companyName,
                          validator: FormBuilderValidators.required(
                            errorText: 'Company name is required.',
                          ),
                        ),
                        Gap(AppSpacing.md.h),
                        const FieldLabel('ABN'),
                        Gap(AppSpacing.sm.h),
                        _FormField(
                          name: 'abn',
                          hint: '12 345 678 901',
                          initialValue: bp?.abn,
                          keyboardType: TextInputType.number,
                        ),
                        Gap(AppSpacing.md.h),
                      ] else ...[
                        const FieldLabel('FULL NAME'),
                        Gap(AppSpacing.sm.h),
                        _FormField(
                          name: 'full_name',
                          hint: 'Your full name',
                          initialValue: tp?.fullName,
                          validator: FormBuilderValidators.required(
                            errorText: 'Full name is required.',
                          ),
                        ),
                        Gap(AppSpacing.md.h),
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
                            style: tt.bodySmall!.copyWith(
                              color: c.urgent,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                        Gap(AppSpacing.md.h),
                      ],
                      const FieldLabel('DISPLAY NAME'),
                      Gap(AppSpacing.sm.h),
                      _FormField(
                        name: 'display_name',
                        hint: 'How you appear in the app',
                        initialValue: profile?.displayName,
                        validator: FormBuilderValidators.required(
                          errorText: 'Display name is required.',
                        ),
                      ),
                      Gap(AppSpacing.md.h),
                      FieldLabel(isBuilder ? 'SERVICE SUBURB' : 'BASE SUBURB'),
                      Gap(AppSpacing.sm.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _FormField(
                              name: 'suburb',
                              hint: 'Suburb',
                              initialValue: isBuilder
                                  ? bp?.serviceSuburb
                                  : tp?.baseSuburb,
                              validator: FormBuilderValidators.required(
                                errorText: 'Suburb is required.',
                              ),
                            ),
                          ),
                          Gap(10.w),
                          Expanded(
                            flex: 2,
                            child: _FormField(
                              name: 'state',
                              hint: 'State',
                              initialValue: isBuilder
                                  ? bp?.serviceState
                                  : tp?.baseState,
                            ),
                          ),
                        ],
                      ),
                      Gap(AppSpacing.md.h),
                      if (isBuilder) ...[
                        const FieldLabel('CONTACT PHONE'),
                        Gap(AppSpacing.sm.h),
                        _FormField(
                          name: 'contact_phone',
                          hint: '+61 4 1234 5678',
                          initialValue: bp?.contactPhone,
                          keyboardType: TextInputType.phone,
                        ),
                        Gap(AppSpacing.md.h),
                      ],
                      const FieldLabel('ABOUT'),
                      Gap(AppSpacing.sm.h),
                      _FormField(
                        name: 'about',
                        hint: isBuilder
                            ? 'Tell tradies about your company…'
                            : 'Tell builders about your experience…',
                        initialValue: isBuilder ? bp?.about : tp?.about,
                        maxLines: 4,
                      ),

                      // ── Verification + portfolio ─────────────────────
                      // Status rows for the slots the T1 completeness banner
                      // grades on. Each row reads the same field the SQL view
                      // does so the screen and the banner always agree.
                      Gap(AppSpacing.lg.h),
                      const FieldLabel('VERIFICATION'),
                      Gap(AppSpacing.sm.h),
                      _StatusRow(
                        icon: Iconsax.call,
                        label: 'Phone',
                        done: profile?.isPhoneVerified ?? false,
                        ctaLabel: 'VERIFY',
                        onCta: () => context.push('/profile/verify-phone'),
                      ),
                      if (!isBuilder) ...[
                        Gap(8.h),
                        _StatusRow(
                          icon: Iconsax.document_text,
                          label: 'Trade licence',
                          done: tp?.hasLicence ?? false,
                          ctaLabel: 'UPLOAD',
                          onCta: () => context.push('/verification'),
                        ),
                        Gap(AppSpacing.lg.h),
                        const FieldLabel('PORTFOLIO'),
                        Gap(AppSpacing.sm.h),
                        const PortfolioStrip(),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ── Save button
            Container(
              decoration: BoxDecoration(
                color: c.card,
                border: Border(top: BorderSide(color: c.border)),
              ),
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
              child: GestureDetector(
                onTap: isSaving ? null : _save,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: isSaving ? c.surfaceRaised : c.action,
                    borderRadius: BorderRadius.circular(AppRadius.btn.r),
                  ),
                  alignment: Alignment.center,
                  child: isSaving
                      ? SizedBox(
                          width: 20.r,
                          height: 20.r,
                          child: CircularProgressIndicator(
                            color: c.text1,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'SAVE CHANGES',
                          style: tt.titleMedium!.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Colors.white, // intentional: white-on-action
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// FormBuilder-aware text field with the bordered-surface chrome that matches
// the rest of /profile/edit. Helper-space is reserved so validation errors
// don't push the form's layout around.
class _FormField extends StatelessWidget {
  const _FormField({
    required this.name,
    required this.hint,
    this.initialValue,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String name;
  final String hint;
  final String? initialValue;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    // The themed OutlineInputBorder owns the box, so Material renders the
    // validation error BELOW/outside the field instead of inside the border.
    // Mirrors JTextField (the auth-flow pattern) and MASTER “Input Fields”.
    return FormBuilderTextField(
      name: name,
      initialValue: initialValue,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: tt.bodyLarge!.copyWith(
        color: c.text1,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        // Reserve helper/error space so layout doesn't jump on validation.
        helperText: ' ',
        helperMaxLines: 2,
        errorMaxLines: 2,
      ),
    );
  }
}

// Tappable input-shaped tile that mirrors _FormField's chrome and opens the
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
              Icon(Iconsax.arrow_down_1, size: 16.r, color: c.text3),
            ],
          ),
        ),
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
          Icon(icon, size: 18.r, color: done ? c.verified : c.text3),
          Gap(12.w),
          Expanded(
            child: Text(label, style: tt.bodyMedium!.copyWith(color: c.text1)),
          ),
          if (done)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.tick_circle, size: 16.r, color: c.verified),
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
