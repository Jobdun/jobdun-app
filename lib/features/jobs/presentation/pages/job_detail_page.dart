import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/bottom_action_bar.dart';
import '../../../../core/design/widgets/field_label.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_chip.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../applications/presentation/providers/applications_provider.dart';
import 'job_apply_sheet.dart';
import 'job_detail_args.dart';

export 'job_detail_args.dart';

class JobDetailPage extends ConsumerStatefulWidget {
  const JobDetailPage({super.key, required this.args});

  final JobDetailArgs args;

  @override
  ConsumerState<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends ConsumerState<JobDetailPage> {
  bool _applied = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final args = widget.args;

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
                      AppIcons.back,
                      size: AppIconSize.md.r,
                      color: c.text1,
                    ),
                  ),
                  Expanded(
                    child: PageHeader(
                      eyebrow: 'JOB DETAILS',
                      title: args.title,
                      size: PageHeaderSize.sub,
                    ),
                  ),
                  if (args.isUrgent) ...[
                    Gap(AppSpacing.sm.w),
                    const JChip(label: 'URGENT'),
                  ],
                ],
              ),
            ),
            Divider(height: 1, color: c.border),

            // ── Body
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, AppSpacing.lg.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Key stats chips
                    Wrap(
                      spacing: AppSpacing.sm.w,
                      runSpacing: AppSpacing.sm.h,
                      children: [
                        _InfoChip(icon: AppIcons.wallet, label: args.rate),
                        _InfoChip(
                          icon: AppIcons.calendar,
                          label: args.startDate,
                        ),
                        if (args.distanceKm > 0)
                          _InfoChip(
                            icon: AppIcons.location,
                            label:
                                '${args.distanceKm.toStringAsFixed(1)} km away',
                          ),
                      ],
                    ),
                    Gap(20.h),

                    // ── Location
                    if (args.suburb != null || args.state != null) ...[
                      FieldLabel('LOCATION'),
                      Gap(AppSpacing.sm.h),
                      Row(
                        children: [
                          Icon(
                            AppIcons.location,
                            size: AppIconSize.inline.r,
                            color: c.text3,
                          ),
                          Gap(AppSpacing.sm.w),
                          Text(
                            [
                              args.suburb,
                              args.state,
                            ].whereType<String>().join(', '),
                            style: tt.bodyLarge!.copyWith(
                              fontWeight: FontWeight.w600,
                              color: c.text1,
                            ),
                          ),
                        ],
                      ),
                      Gap(20.h),
                    ],

                    // ── Trade type
                    FieldLabel('TRADE REQUIRED'),
                    Gap(AppSpacing.sm.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: c.action.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.chip.r),
                        border: Border.all(
                          color: c.action.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        args.tradeType,
                        style: tt.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.action,
                        ),
                      ),
                    ),
                    Gap(20.h),

                    // ── Description
                    FieldLabel('JOB DESCRIPTION'),
                    Gap(AppSpacing.sm.h),
                    Text(
                      args.description,
                      style: tt.bodyLarge!.copyWith(
                        color: c.text2,
                        height: 1.6,
                      ),
                    ),
                    Gap(20.h),

                    // ── Posted by
                    FieldLabel('POSTED BY'),
                    Gap(AppSpacing.sm.h),
                    Container(
                      padding: EdgeInsets.all(14.r),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(AppRadius.card.r),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44.r,
                            height: 44.r,
                            decoration: BoxDecoration(
                              color: c.surfaceRaised,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.border),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              args.builderInitials ?? 'B',
                              style: tt.titleLarge!.copyWith(
                                fontWeight: FontWeight.w700,
                                color: c.text2,
                              ),
                            ),
                          ),
                          Gap(12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  args.companyName ?? 'Builder',
                                  style: tt.titleMedium!.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: c.text1,
                                  ),
                                ),
                                // TODO(core-loop): surface the real builder
                                // rating + review count and a verified badge
                                // once JobDetailArgs carries builder_profiles
                                // data. No fabricated rating/badge until then.
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gap(20.h),

                    // ── Requirements
                    FieldLabel('REQUIREMENTS'),
                    Gap(10.h),
                    _ReqRow(
                      icon: AppIcons.licence,
                      label: 'Current trade licence required',
                      met: true,
                    ),
                    if (args.requiresWhiteCard)
                      _ReqRow(
                        icon: AppIcons.card,
                        label: 'White card required',
                        met: true,
                      ),
                    if (args.requiresLiability)
                      _ReqRow(
                        icon: AppIcons.policy,
                        label: 'Public liability insurance (\$10M+)',
                        met: true,
                      ),
                    _ReqRow(
                      icon: AppIcons.document,
                      label: 'SWMS to be provided on site',
                      met: false,
                    ),
                  ],
                ),
              ),
            ),

            _applied
                ? Container(
                    decoration: BoxDecoration(
                      color: c.card,
                      border: Border(top: BorderSide(color: c.border)),
                    ),
                    padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
                    child: Container(
                      width: double.infinity,
                      height: 48.h,
                      decoration: BoxDecoration(
                        color: c.verifiedBg,
                        borderRadius: BorderRadius.circular(AppRadius.btn.r),
                        border: Border.all(color: c.verified),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppIcons.successCircle,
                            size: AppIconSize.md.r,
                            color: c.verified,
                          ),
                          Gap(AppSpacing.sm.w),
                          Text(
                            'APPLICATION SUBMITTED',
                            style: tt.bodyLarge!.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: c.verifiedTx,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : BottomActionBar(
                    primary: JButton(
                      label: 'APPLY NOW',
                      onPressed: () => _showApplySheet(context, c, args),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _showApplySheet(BuildContext context, JColors c, JobDetailArgs args) {
    final tt = Theme.of(context).textTheme;
    final messenger = ScaffoldMessenger.of(context);
    showJSheet<void>(
      context: context,
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) => JobApplySheet(
        args: args,
        onSubmit: (rate, note) async {
          final jobId = args.id;
          if (jobId == null) {
            Navigator.pop(ctx);
            _showError(
              messenger,
              c,
              tt,
              'This is a sample listing — open a real job to apply.',
            );
            return;
          }
          final ok = await ref
              .read(applicationsControllerProvider.notifier)
              .apply(
                jobId: jobId,
                coverNote: note,
                proposedRate: rate,
                proposedRateType: 'Hourly',
              );
          if (!ctx.mounted) return;
          if (ok) {
            Navigator.pop(ctx);
            if (mounted) setState(() => _applied = true);
          } else {
            final err =
                ref.read(applicationsControllerProvider).error ??
                'Could not submit application. Please try again.';
            _showError(messenger, c, tt, err);
          }
        },
      ),
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
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.chip.r),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.micro.r, color: c.text3),
          Gap(6.w),
          Text(label, style: tt.labelMedium!.copyWith(color: c.text2)),
        ],
      ),
    );
  }
}

class _ReqRow extends StatelessWidget {
  const _ReqRow({required this.icon, required this.label, required this.met});
  final IconData icon;
  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppIconSize.inline.r,
            color: met ? c.text2 : c.text3,
          ),
          Gap(10.w),
          Expanded(
            child: Text(
              label,
              style: tt.bodyMedium!.copyWith(color: met ? c.text2 : c.text3),
            ),
          ),
        ],
      ),
    );
  }
}
