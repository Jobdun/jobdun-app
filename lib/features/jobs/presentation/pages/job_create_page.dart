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
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_select_chip.dart';
import '../../../../core/design/widgets/j_switch.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/services/places_service.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
import '../../../verification/presentation/providers/verifications_provider.dart';
import '../../domain/entities/job.dart';
import '../providers/jobs_provider.dart';
import '../widgets/job_location_field.dart';

part 'job_create_page_widgets.dart';
part 'job_create_helpers.dart';
part 'job_create_step_one.dart';
part 'job_create_step_two.dart';

class JobCreatePage extends ConsumerStatefulWidget {
  const JobCreatePage({super.key});

  @override
  ConsumerState<JobCreatePage> createState() => _JobCreatePageState();
}

class _JobCreatePageState extends ConsumerState<JobCreatePage> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _pageController = PageController();
  bool _isPosting = false;

  /// Which Figma frame is showing — 0 = details (134:13408), 1 = pricing
  /// (134:13313).
  int _step = 0;
  static const _totalSteps = 2;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
    if (_isPosting) return;
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

    // Flip BEFORE the await: two taps = two listings (P0, 2026-08-18).
    setState(() => _isPosting = true);

    // Soft gate: only Verified (ABN) businesses publish; unverified go via
    // the ABN wizard then retry. RLS is the hard backstop.
    final verified = await _isVerifiedBusiness(builderId);
    if (!context.mounted) return;
    if (!verified) {
      setState(() => _isPosting = false);
      HapticFeedback.mediumImpact();
      await showJSheet<void>(
        context: context,
        builder: (_) => const _VerifyGateSheet(),
      );
      return;
    }
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
        // Refresh the feed + bust builder aggregate caches so the new post
        // shows immediately everywhere.
        ref.read(jobsControllerProvider.notifier).refresh();
        invalidateBuilderJobAggregates(ref);
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

  // ── Step machine ─────────────────────────────────────────────────────────
  //
  // Figma splits Post a Job across two frames (134:13408 → 134:13313). The
  // form itself is unchanged — one [FormBuilder] still wraps both pages, so
  // values survive paging back and `_post` reads the whole map exactly as it
  // did when this was a single scroll.

  /// Fields the builder must satisfy before step 2 unlocks. `place` is checked
  /// separately because the legacy fallback splits it into three fields.
  static const _stepOneFields = ['title', 'description', 'trade'];

  bool get _stepOneComplete {
    final st = _formKey.currentState;
    if (st == null) return false;
    for (final name in _stepOneFields) {
      final v = st.fields[name]?.value;
      if (v == null || (v is String && v.trim().isEmpty)) return false;
    }
    return _hasLocation(st);
  }

  bool _hasLocation(FormBuilderState st) {
    if (st.fields['place']?.value != null) return true;
    final suburb = st.fields['suburb']?.value as String?;
    return suburb != null && suburb.trim().isNotEmpty;
  }

  void _goToStep(int next) {
    if (next == _step) return;
    // Leaving step 1 forward: validate so inline errors appear rather than
    // silently carrying an invalid title into the pricing page.
    if (next > _step) {
      final st = _formKey.currentState;
      if (st == null) return;
      var ok = true;
      for (final name in [..._stepOneFields, 'place', 'suburb']) {
        final f = st.fields[name];
        if (f != null && !f.validate()) ok = false;
      }
      if (!ok || !_hasLocation(st)) {
        HapticFeedback.heavyImpact();
        _scrollToFirstError(st);
        return;
      }
    }
    HapticFeedback.selectionClick();
    setState(() => _step = next);
    _pageController.animateToPage(
      next,
      duration: AppMotion.medium,
      curve: AppMotion.standard,
    );
  }

  /// Back caret: step 2 returns to step 1; step 1 leaves the flow.
  void _onBack() {
    if (_step > 0) {
      _goToStep(_step - 1);
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: FormBuilder(
          key: _formKey,
          // Rebuild on every field change so the step-1 footer can enable
          // itself the moment the last required value lands.
          onChanged: () => setState(() {}),
          initialValue: const {
            'pricingMode': PricingType.builderSet,
            'pricingUnit': PricingUnit.hourly,
            'urgent': false,
          },
          child: Column(
            children: [
              _JobCreateHeader(
                step: _step,
                totalSteps: _totalSteps,
                onBack: _onBack,
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  // Paging is driven by the footer buttons only — a stray
                  // horizontal drag must not skip past validation.
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StepOne(
                      trades: _trades,
                      onTradeChanged: (t) => setState(() => _selectedTrade = t),
                    ),
                    _StepTwo(
                      pricingMode: _pricingMode,
                      pricingUnit: _pricingUnit,
                      rateHint: _rateHint(),
                      onModeChanged: (m) => setState(() => _pricingMode = m),
                      onUnitChanged: (u) => setState(() => _pricingUnit = u),
                    ),
                  ],
                ),
              ),
              BottomActionBar(
                primary: _step == 0
                    ? JButton(
                        label: 'Next',
                        onPressed: _stepOneComplete ? () => _goToStep(1) : null,
                      )
                    : JButton(
                        label: _isPosting ? 'Posting…' : 'Post Job',
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

/// Post-a-Job header (Figma node 134:13409): back caret, title, step counter.
class _JobCreateHeader extends StatelessWidget {
  const _JobCreateHeader({
    required this.step,
    required this.totalSteps,
    required this.onBack,
  });

  final int step;
  final int totalSteps;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 8.h, 16.w, 8.h),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(AppIcons.back, size: AppIconSize.md.r, color: c.text1),
            tooltip: step > 0 ? 'Back a step' : 'Close',
          ),
          Expanded(
            child: Text(
              'Post a Job',
              style: tt.headlineSmall!.copyWith(
                fontSize: 24,
                height: 1.2,
                color: c.text1,
              ),
            ),
          ),
          Semantics(
            label: 'Step ${step + 1} of $totalSteps',
            child: Text(
              '${step + 1}/$totalSteps',
              style: tt.titleMedium!.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
                // The mock uses the fill orange here; at 16dp that is 3.34:1,
                // so the ink token carries it (4.92:1).
                color: c.actionInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
