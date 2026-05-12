import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_gradients.dart';
import '../../../../core/design/widgets/field_label.dart';

class JobCreatePage extends StatefulWidget {
  const JobCreatePage({super.key});

  @override
  State<JobCreatePage> createState() => _JobCreatePageState();
}

class _JobCreatePageState extends State<JobCreatePage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _suburbCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();

  String? _selectedTrade;
  String _rateType = 'Hourly';
  bool _isUrgent = false;
  bool _isPosting = false;

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

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _suburbCtrl.dispose();
    _stateCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _post(BuildContext context, JColors c) async {
    final tt = Theme.of(context).textTheme;
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Job title is required.',
            style: tt.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
          ),
          backgroundColor: c.urgent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isPosting = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _isPosting = false);
    router.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Iconsax.tick_circle,
              size: 18.r,
              color: Colors.white, // intentional
            ),
            Gap(10.w),
            Text(
              'Job posted successfully!',
              style: tt.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white, // intentional: white-on-action
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
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
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
                      Iconsax.close_circle,
                      size: 22.r,
                      color: c.text1,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEW LISTING',
                          style: tt.labelSmall!.copyWith(
                            letterSpacing: 0.12 * 11,
                            color: c.text3,
                          ),
                        ),
                        Gap(2.h),
                        ShaderMask(
                          shaderCallback: (b) =>
                              AppGradients.brandFlame.createShader(b),
                          child: Text(
                            'Post a Job',
                            style: tt.headlineSmall!.copyWith(
                              fontSize: 22.sp,
                              color: Colors
                                  .white, // intentional: ShaderMask requires white for gradient
                            ),
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
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, AppSpacing.lg.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Job title
                    FieldLabel('JOB TITLE'),
                    Gap(AppSpacing.sm.h),
                    _InputField(
                      controller: _titleCtrl,
                      hint:
                          'e.g. Install 3-phase switchboard at commercial site',
                    ),
                    Gap(20.h),

                    // ── Trade type
                    FieldLabel('TRADE REQUIRED'),
                    Gap(10.h),
                    Wrap(
                      spacing: AppSpacing.sm.w,
                      runSpacing: AppSpacing.sm.h,
                      children: _trades.map((t) {
                        final active = _selectedTrade == t;
                        return GestureDetector(
                          onTap: () => setState(
                            () => _selectedTrade = active ? null : t,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 7.h,
                            ),
                            decoration: BoxDecoration(
                              color: active ? c.action : c.surface,
                              borderRadius: BorderRadius.circular(
                                AppRadius.chip.r,
                              ),
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
                                          .white // intentional
                                    : c.text2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    Gap(20.h),

                    // ── Location
                    FieldLabel('LOCATION'),
                    Gap(AppSpacing.sm.h),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _InputField(
                            controller: _suburbCtrl,
                            hint: 'Suburb',
                          ),
                        ),
                        Gap(10.w),
                        Expanded(
                          flex: 2,
                          child: _InputField(
                            controller: _stateCtrl,
                            hint: 'State',
                          ),
                        ),
                      ],
                    ),
                    Gap(20.h),

                    // ── Rate
                    FieldLabel('RATE'),
                    Gap(AppSpacing.sm.h),
                    Row(
                      children: _rateTypes.map((rt) {
                        final active = _rateType == rt;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _rateType = rt),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: EdgeInsets.only(
                                right: rt != _rateTypes.last
                                    ? AppSpacing.sm.w
                                    : 0,
                              ),
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              decoration: BoxDecoration(
                                color: active ? c.action : c.surface,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.chip.r,
                                ),
                                border: Border.all(
                                  color: active ? c.action : c.border,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                rt,
                                style: tt.bodyMedium!.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: active
                                      ? Colors
                                            .white // intentional
                                      : c.text2,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    Gap(10.h),
                    Container(
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(AppRadius.input.r),
                        border: Border.all(color: c.border),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 4.h,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '\$',
                            style: tt.headlineSmall!.copyWith(
                              fontSize: 20.sp,
                              color: c.text3,
                            ),
                          ),
                          Gap(4.w),
                          Expanded(
                            child: TextField(
                              controller: _rateCtrl,
                              keyboardType: TextInputType.number,
                              style: tt.headlineSmall!.copyWith(
                                fontSize: 20.sp,
                                color: c.text1,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                                hintText: '85',
                              ),
                            ),
                          ),
                          Text(
                            _rateType == 'Hourly'
                                ? '/hr'
                                : _rateType == 'Daily'
                                ? '/day'
                                : 'flat',
                            style: tt.bodyMedium!.copyWith(color: c.text3),
                          ),
                        ],
                      ),
                    ),
                    Gap(20.h),

                    // ── Description
                    FieldLabel('DESCRIPTION'),
                    Gap(AppSpacing.sm.h),
                    Container(
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(AppRadius.input.r),
                        border: Border.all(color: c.border),
                      ),
                      child: TextField(
                        controller: _descCtrl,
                        maxLines: 5,
                        style: tt.bodyMedium!.copyWith(color: c.text1),
                        decoration: InputDecoration(
                          hintText:
                              'Describe the scope of work, site conditions, tools required…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.all(14.r),
                        ),
                      ),
                    ),
                    Gap(20.h),

                    // ── Urgency toggle
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md.w,
                        vertical: 14.h,
                      ),
                      decoration: BoxDecoration(
                        color: _isUrgent ? c.actionBg : c.surface,
                        borderRadius: BorderRadius.circular(AppRadius.card.r),
                        border: Border.all(
                          color: _isUrgent ? c.action : c.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Iconsax.flash_1,
                            size: 18.r,
                            color: _isUrgent ? c.action : c.text3,
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
                                    color: _isUrgent ? c.action : c.text1,
                                  ),
                                ),
                                Gap(2.h),
                                Text(
                                  'Shown to more tradies, listed at the top',
                                  style: tt.labelMedium!.copyWith(
                                    color: c.text3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isUrgent,
                            onChanged: (v) => setState(() => _isUrgent = v),
                            activeThumbColor:
                                Colors.white, // intentional: white-on-action
                            activeTrackColor: c.action,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Post button
            Container(
              decoration: BoxDecoration(
                color: c.card,
                border: Border(top: BorderSide(color: c.border)),
              ),
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
              child: GestureDetector(
                onTap: _isPosting ? null : () => _post(context, c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: _isPosting ? c.surfaceRaised : c.action,
                    borderRadius: BorderRadius.circular(AppRadius.btn.r),
                  ),
                  alignment: Alignment.center,
                  child: _isPosting
                      ? SizedBox(
                          width: 20.r,
                          height: 20.r,
                          child: CircularProgressIndicator(
                            color: c.text1,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Iconsax.send_1,
                              size: 18.r,
                              color: Colors.white, // intentional
                            ),
                            Gap(AppSpacing.sm.w),
                            Text(
                              'POST JOB',
                              style: tt.titleMedium!.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: Colors
                                    .white, // intentional: white-on-action
                              ),
                            ),
                          ],
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

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  const _InputField({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.input.r),
        border: Border.all(color: c.border),
      ),
      child: TextField(
        controller: controller,
        style: tt.bodyLarge!.copyWith(color: c.text1),
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14.w,
            vertical: 13.h,
          ),
          isDense: true,
        ),
      ),
    );
  }
}
