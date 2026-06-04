import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/bottom_action_bar.dart';
import '../../../../core/design/widgets/field_label.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_switch.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/services/places_service.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
import '../../../verification/presentation/providers/verifications_provider.dart';
import '../../domain/entities/job.dart';
import '../providers/jobs_provider.dart';
import '../widgets/job_location_field.dart';

part 'job_create_page_widgets.dart';

class JobCreatePage extends ConsumerStatefulWidget {
  const JobCreatePage({super.key});

  @override
  ConsumerState<JobCreatePage> createState() => _JobCreatePageState();
}

class _JobCreatePageState extends ConsumerState<JobCreatePage> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isPosting = false;

  // Mirrors the active pricing unit + mode into local state so the amount
  // field's suffix and visibility can react without rebuilding the whole form
  // via the FormBuilder controller every keystroke.
  PricingUnit _pricingUnit = PricingUnit.hourly;
  PricingType _pricingMode = PricingType.builderSet;

  // Mirrors the picked trade so the rate field can show a trade-aware hourly
  // guide without reading the FormBuilder controller on every build.
  String? _selectedTrade;

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

  // Ballpark AUD hourly rates by trade — a guide shown under the rate field,
  // never a quote. Used only for the 'Hourly' rate type.
  static const _typicalHourly = <String, int>{
    'Electrician': 85,
    'Plumber': 90,
    'Carpenter': 70,
    'Concreter': 75,
    'Painter': 60,
    'Roofer': 70,
    'Welder': 75,
    'Labourer': 45,
  };

  Future<void> _post(BuildContext context, JColors c) async {
    final tt = Theme.of(context).textTheme;
    final formState = _formKey.currentState;
    if (formState == null || !formState.saveAndValidate()) {
      HapticFeedback.heavyImpact();
      _scrollToFirstError(formState);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final builderId = ref.read(currentUserIdSyncProvider);
    if (builderId == null) {
      HapticFeedback.heavyImpact();
      _showError(messenger, c, tt, 'You must be signed in to post a job.');
      return;
    }

    // Soft gate: only Verified businesses (ABN) can publish a job. Unverified
    // builders are routed through the ~15s ABN wizard, then they retry POST.
    // The form stays intact behind the sheet. RLS is the hard backstop.
    final verified = await _isVerifiedBusiness(builderId);
    if (!context.mounted) return;
    if (!verified) {
      HapticFeedback.mediumImpact();
      await showJSheet<void>(
        context: context,
        builder: (_) => const _VerifyGateSheet(),
      );
      return;
    }

    setState(() => _isPosting = true);
    final result = await ref
        .read(createJobUseCaseProvider)
        .call(_buildJob(builderId, formState.value));
    if (!mounted) return;
    setState(() => _isPosting = false);

    result.fold(
      (failure) {
        HapticFeedback.heavyImpact();
        _showError(messenger, c, tt, failure.message);
      },
      (_) {
        // Refresh the open-jobs feed so the new listing shows immediately.
        ref.read(jobsControllerProvider.notifier).refresh();
        router.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  AppIcons.successCircle,
                  size: AppIconSize.md.r,
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
      },
    );
  }

  /// True when the builder is a Verified business (ABN verified). Fail-open on
  /// a transient lookup error — the jobs-insert RLS backstop is the hard gate.
  Future<bool> _isVerifiedBusiness(String builderId) async {
    try {
      final rows = await ref.read(
        verificationsForUserProvider(builderId).future,
      );
      return summariseForBuilder(rows) == VerificationSummary.fullyVerified;
    } catch (_) {
      return true;
    }
  }

  void _showError(
    ScaffoldMessengerState messenger,
    JColors c,
    TextTheme tt,
    String message,
  ) {
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              AppIcons.urgent,
              size: AppIconSize.md.r,
              color: Colors.white, // intentional: white-on-error
            ),
            Gap(10.w),
            Expanded(
              child: Text(
                message,
                style: tt.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white, // intentional: white-on-error
                ),
              ),
            ),
          ],
        ),
        backgroundColor: c.urgent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Maps the validated form into a domain [Job]. `id`/timestamps are
  /// placeholders — `JobModel.toJson` drops them so the DB generates them.
  Job _buildJob(String builderId, Map<String, dynamic> values) {
    final now = DateTime.now();
    final rate = double.tryParse('${values['rate'] ?? ''}');
    final pricingType =
        values['pricingMode'] as PricingType? ?? PricingType.builderSet;
    final pricingUnit =
        values['pricingUnit'] as PricingUnit? ?? PricingUnit.hourly;

    // Location resolves two ways: the MapTiler picker emits a single
    // JPlaceResult under 'place'; the legacy fallback emits suburb / state /
    // postcode as separate fields.
    var suburb = '';
    var state = '';
    var postcode = '';
    double? latitude;
    double? longitude;
    String? formattedAddress;
    String? placeId;
    final place = values['place'];
    if (place is JPlaceResult) {
      suburb = place.suburb;
      state = place.state;
      postcode = place.postcode;
      latitude = place.latitude;
      longitude = place.longitude;
      formattedAddress = place.formattedAddress;
      placeId = place.placeId;
    } else {
      suburb = (values['suburb'] as String? ?? '').trim();
      state = (values['state'] as String? ?? '').trim().toUpperCase();
      postcode = (values['postcode'] as String? ?? '').trim();
    }

    return Job(
      id: '',
      builderId: builderId,
      title: (values['title'] as String).trim(),
      description: (values['description'] as String).trim(),
      tradeTypeRequired: values['trade'] as String,
      suburb: suburb,
      state: state,
      postcode: postcode,
      status: JobStatus.open,
      createdAt: now,
      updatedAt: now,
      // budget_amount only when the builder named a price; null for
      // request_quote (matches the jobs_budget_amount_when_set CHECK).
      budgetAmount: pricingType == PricingType.builderSet ? rate : null,
      pricingType: pricingType,
      pricingUnit: pricingUnit,
      urgency: (values['urgent'] as bool? ?? false)
          ? JobUrgency.urgent
          : JobUrgency.standard,
      latitude: latitude,
      longitude: longitude,
      formattedAddress: formattedAddress,
      placeId: placeId,
    );
  }

  /// Trade-aware hourly-rate guide for the rate field's helper slot. Returns
  /// null for non-hourly types or unknown trades so the slot stays empty.
  String? _rateHint() {
    final trade = _selectedTrade;
    if (_pricingMode != PricingType.builderSet ||
        _pricingUnit != PricingUnit.hourly ||
        trade == null) {
      return null;
    }
    final typical = _typicalHourly[trade];
    if (typical == null) return null;
    return 'Most ${trade.toLowerCase()}s nearby charge around \$$typical/hr.';
  }

  /// On a failed submit, scrolls the first invalid field into view so the
  /// builder sees what's blocking POST instead of just feeling a haptic with
  /// the error off-screen. Order mirrors the visual top-to-bottom layout.
  void _scrollToFirstError(FormBuilderState? formState) {
    if (formState == null) return;
    const order = [
      'title',
      'trade',
      'description',
      'place',
      'suburb',
      'state',
      'postcode',
      'rate',
    ];
    for (final name in order) {
      final field = formState.fields[name];
      if (field != null && field.hasError) {
        Scrollable.ensureVisible(
          field.context,
          alignment: 0.1,
          duration: AppMotion.medium,
          curve: AppMotion.standard,
        );
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: FormBuilder(
          key: _formKey,
          initialValue: const {
            'pricingMode': PricingType.builderSet,
            'pricingUnit': PricingUnit.hourly,
            'urgent': false,
          },
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
                        size: AppIconSize.md.r,
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

                      Gap(20.h),
                      _TradePicker(
                        trades: _trades,
                        onChanged: (t) => setState(() => _selectedTrade = t),
                      ),
                      Gap(20.h),

                      // Description sits with the title + trade — together they
                      // are "the job" the builder is describing.
                      JTextField(
                        name: 'description',
                        label: 'DESCRIPTION',
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

                      // ── Where ──────────────────────────────────────────────
                      Gap(AppSpacing.xl.h),
                      const JobLocationField(),

                      // ── Pricing: mode toggle + unit, then the amount (only
                      // when the builder names a price; request-quote jobs
                      // collect tradie quotes instead).
                      Gap(AppSpacing.xl.h),
                      const FieldLabel('PRICING'),
                      Gap(8.h),
                      _PricingModePicker(
                        onChanged: (m) => setState(() => _pricingMode = m),
                      ),
                      Gap(AppSpacing.md.h),
                      const FieldLabel('PRICED PER'),
                      Gap(8.h),
                      _PricingUnitPicker(
                        onChanged: (u) => setState(() => _pricingUnit = u),
                      ),
                      Gap(AppSpacing.md.h),
                      if (_pricingMode == PricingType.builderSet)
                        JTextField(
                          name: 'rate',
                          // Persistent "$" via the always-visible prefix slot,
                          // mirroring the always-on unit suffix.
                          prefix: Padding(
                            padding: EdgeInsets.only(left: 16.w, right: 6.w),
                            child: Text(
                              '\$',
                              style: Theme.of(context).textTheme.bodyLarge!
                                  .copyWith(
                                    color: c.text1,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                          hint: '85',
                          helperText: _rateHint(),
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          suffixIcon: Padding(
                            padding: EdgeInsets.only(right: 12.w),
                            child: Text(
                              _pricingUnit.suffix.isEmpty
                                  ? 'total'
                                  : _pricingUnit.suffix,
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
                        )
                      else
                        Container(
                          padding: EdgeInsets.all(AppSpacing.md.r),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(
                              AppRadius.card.r,
                            ),
                            border: Border.all(color: c.border),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.quote,
                                size: AppIconSize.md.r,
                                color: c.text3,
                              ),
                              Gap(10.w),
                              Expanded(
                                child: Text(
                                  'Tradies send their quotes when they apply. '
                                  "You'll see each quote on the Applicants screen.",
                                  style: Theme.of(context).textTheme.bodyMedium!
                                      .copyWith(color: c.text2, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ── Visibility ─────────────────────────────────────────
                      Gap(AppSpacing.xl.h),
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

// Form sub-widgets (_TradePicker / _RateTypePicker / _UrgentToggle) live in
// job_create_page_widgets.dart (a `part` of this file) to keep this page under
// the 500 LOC ceiling.
