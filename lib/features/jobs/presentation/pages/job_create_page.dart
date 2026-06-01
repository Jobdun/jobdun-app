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
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_switch.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/services/places_service.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
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
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final builderId = ref.read(currentUserIdSyncProvider);
    if (builderId == null) {
      HapticFeedback.heavyImpact();
      _showError(messenger, c, tt, 'You must be signed in to post a job.');
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
    final budgetType = switch (values['rateType'] as String? ?? 'Hourly') {
      'Daily' => BudgetType.daily,
      'Fixed' => BudgetType.fixed,
      _ => BudgetType.hourly,
    };

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
      budgetMin: rate,
      budgetType: budgetType,
      urgency: (values['urgent'] as bool? ?? false)
          ? JobUrgency.urgent
          : JobUrgency.standard,
      latitude: latitude,
      longitude: longitude,
      formattedAddress: formattedAddress,
      placeId: placeId,
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

// Form sub-widgets (_TradePicker / _RateTypePicker / _UrgentToggle) live in
// job_create_page_widgets.dart (a `part` of this file) to keep this page under
// the 500 LOC ceiling.
