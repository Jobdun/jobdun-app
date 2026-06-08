import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/app/constants/app_strings.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/bottom_action_bar.dart';
import '../../../../core/design/widgets/field_label.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_chip.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../applications/presentation/pages/job_applicants_args.dart';
import '../../../applications/presentation/providers/applications_provider.dart';
import '../providers/jobs_provider.dart';
import 'job_apply_sheet.dart';
import 'job_detail_args.dart';

export 'job_detail_args.dart';

part 'job_detail_page_widgets.dart';

class JobDetailPage extends ConsumerStatefulWidget {
  const JobDetailPage({super.key, required this.args});

  final JobDetailArgs args;

  @override
  ConsumerState<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends ConsumerState<JobDetailPage> {
  bool _applied = false;

  @override
  void initState() {
    super.initState();
    // Load the tradie's applications so an already-applied job shows the
    // "Applied" state instead of a re-apply button (which would hit the
    // UNIQUE(job_id, trade_id) constraint and surface a raw error).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final me = ref.read(currentUserIdSyncProvider);
      if (me != null) {
        ref
            .read(applicationsControllerProvider.notifier)
            .loadMyApplications(me);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final args = widget.args;
    // True once the tradie has applied — locally this session, or per the
    // loaded application list (survives leaving and re-opening the job).
    final applied =
        _applied ||
        (args.id != null &&
            ref.watch(
              applicationsControllerProvider.select(
                (s) => s.myApplications.any((a) => a.jobId == args.id),
              ),
            ));
    // The viewer owns this listing → manage it, never apply to it.
    final isOwner =
        args.builderId != null &&
        args.builderId == ref.watch(currentUserIdSyncProvider);

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
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // Tap through to the public builder profile (S13) —
                      // company, ABN ✓, track record, reviews from tradies — so
                      // a tradie can vet who they're applying to before they do.
                      onTap: args.builderId == null
                          ? null
                          : () => context.push('/builders/${args.builderId}'),
                      child: Container(
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
                                  if (args.builderId != null) ...[
                                    Gap(2.h),
                                    Text(
                                      'View profile & reviews',
                                      style: tt.bodySmall!.copyWith(
                                        color: c.action,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (args.builderId != null)
                              Icon(
                                AppIcons.chevronRight,
                                size: AppIconSize.inline.r,
                                color: c.text3,
                              ),
                          ],
                        ),
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

            if (isOwner)
              Container(
                decoration: BoxDecoration(
                  color: c.card,
                  border: Border(top: BorderSide(color: c.border)),
                ),
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: JButton(
                        label: 'VIEW APPLICANTS',
                        icon: AppIcons.applicantsOutline,
                        onPressed: () {
                          final jobId = args.id;
                          if (jobId == null) return;
                          final loc = [args.suburb, args.state]
                              .whereType<String>()
                              .where((s) => s.isNotEmpty)
                              .join(', ');
                          context.push(
                            '/jobs/$jobId/applicants',
                            extra: JobApplicantsArgs(
                              jobId: jobId,
                              title: args.title,
                              tradeType: args.tradeType,
                              locationLabel: loc.isEmpty ? null : loc,
                              payLabel: args.rate,
                            ),
                          );
                        },
                      ),
                    ),
                    Gap(10.w),
                    Expanded(
                      child: JButton(
                        label: 'DELETE',
                        icon: AppIcons.trash,
                        variant: JButtonVariant.danger,
                        onPressed: () => _confirmDelete(context, c, args),
                      ),
                    ),
                  ],
                ),
              )
            else if (applied)
              const _AppliedBar()
            else
              BottomActionBar(
                primary: JButton(
                  label: AppStrings.respondToJob,
                  onPressed: () => _showApplySheet(context, c, args),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, JColors c, JobDetailArgs args) {
    final jobId = args.id;
    if (jobId == null) return;
    final tt = Theme.of(context).textTheme;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    showJSheet<void>(
      context: context,
      builder: (ctx) => _DeleteConfirmSheet(
        onConfirm: () async {
          final ok = await ref
              .read(jobsControllerProvider.notifier)
              .deleteJob(jobId);
          if (!ctx.mounted) return;
          Navigator.pop(ctx);
          if (ok && mounted) {
            // Bust the builder aggregate caches so home/profile/listings drop
            // the deleted job instead of serving a stale Phase 1 cache.
            invalidateBuilderJobAggregates(ref);
            router.pop();
            messenger.showSnackBar(
              SnackBar(
                content: const Text('Listing deleted.'),
                backgroundColor: c.surfaceRaised,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (!ok) {
            _showError(
              messenger,
              c,
              tt,
              ref.read(jobsControllerProvider).error ??
                  'Could not delete the listing.',
            );
          }
        },
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
          final builderId = args.builderId;
          if (jobId == null || builderId == null) {
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
                builderId: builderId,
                coverNote: note,
                quoteAmount: rate,
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
