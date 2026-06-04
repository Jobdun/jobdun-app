import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/design/widgets/j_staggered_list.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../domain/entities/job.dart';
import '../providers/jobs_provider.dart';
import 'job_detail_page.dart';

enum _Tab { all, open, filled, closed }

/// Builder's "Your listings" — a management view (status tabs + cards showing
/// the applicant count and quick actions), distinct from the tradie browse
/// feed. Data is the builder's own jobs (one-shot); tabs filter client-side.
class BuilderListingsView extends ConsumerStatefulWidget {
  const BuilderListingsView({super.key});

  @override
  ConsumerState<BuilderListingsView> createState() => _BuilderListingsState();
}

class _BuilderListingsState extends ConsumerState<BuilderListingsView> {
  _Tab _tab = _Tab.all;

  bool _matches(Job j) => switch (_tab) {
    _Tab.all => true,
    _Tab.open => j.status == JobStatus.open,
    _Tab.filled => j.status == JobStatus.filled,
    _Tab.closed =>
      j.status == JobStatus.closed || j.status == JobStatus.cancelled,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final async = ref.watch(builderListingsProvider);
    final all = async.asData?.value ?? const <Job>[];

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header
            Container(
              color: c.card,
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 12.w, 12.h),
              child: Row(
                children: [
                  const Expanded(
                    child: PageHeader(
                      eyebrow: 'MANAGE',
                      title: 'Your listings',
                      size: PageHeaderSize.sub,
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push('/jobs/create'),
                    icon: Icon(
                      AppIcons.addSquare,
                      size: AppIconSize.feature.r,
                      color: c.action,
                    ),
                  ),
                ],
              ),
            ),
            // ── Status tabs
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 4.h),
              child: Container(
                padding: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(AppRadius.btn.r),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    for (final t in _Tab.values)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tab = t),
                          child: Container(
                            height: 34.h,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _tab == t ? c.action : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                AppRadius.chip.r,
                              ),
                            ),
                            child: Text(
                              _tabLabel(t),
                              style: Theme.of(context).textTheme.labelMedium!
                                  .copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _tab == t ? c.onAction : c.text3,
                                  ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: async.isLoading && all.isEmpty
                  ? const _ListingsSkeleton()
                  : _ListingsBody(
                      jobs: all.where(_matches).toList(),
                      tab: _tab,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _tabLabel(_Tab t) => switch (t) {
    _Tab.all => 'All',
    _Tab.open => 'Open',
    _Tab.filled => 'Filled',
    _Tab.closed => 'Closed',
  };
}

class _ListingsBody extends ConsumerWidget {
  const _ListingsBody({required this.jobs, required this.tab});

  final List<Job> jobs;
  final _Tab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (jobs.isEmpty) return _ListingsEmpty(tab: tab);
    return RefreshIndicator(
      color: context.c.action,
      backgroundColor: context.c.surface,
      onRefresh: () => ref.refresh(builderListingsProvider.future),
      child: JStaggeredList(
        padding: EdgeInsets.fromLTRB(
          20.w,
          AppSpacing.sm.h,
          20.w,
          AppSpacing.lg.h,
        ),
        itemCount: jobs.length,
        separatorBuilder: (_, _) => Gap(10.h),
        itemBuilder: (_, i) => _ListingCard(job: jobs[i]),
      ),
    );
  }
}

class _ListingCard extends ConsumerWidget {
  const _ListingCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final statusColor = _statusColor(c, job.status);
    final applicants = job.applicationCount;

    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8.r,
                  height: 8.r,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Gap(6.w),
                Text(
                  job.status.label.toUpperCase(),
                  style: tt.labelSmall!.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: statusColor,
                  ),
                ),
                const Spacer(),
                Icon(
                  AppIcons.applicantsOutline,
                  size: AppIconSize.inline.r,
                  color: applicants > 0 ? c.action : c.text3,
                ),
                Gap(4.w),
                Text(
                  applicants == 1 ? '1 applicant' : '$applicants applicants',
                  style: tt.labelMedium!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: applicants > 0 ? c.action : c.text3,
                  ),
                ),
              ],
            ),
            Gap(10.h),
            Text(
              job.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.titleMedium!.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text1,
              ),
            ),
            Gap(4.h),
            Text(
              '${job.displayBudget} · ${job.suburb} · ${_relPosted(job)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall!.copyWith(color: c.text3),
            ),
            Gap(14.h),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: JButton(
                    label: 'VIEW',
                    size: JButtonSize.compact,
                    icon: AppIcons.applicantsOutline,
                    onPressed: () => _openDetail(context),
                  ),
                ),
                Gap(10.w),
                Expanded(
                  child: JButton(
                    label: 'DELETE',
                    size: JButtonSize.compact,
                    icon: AppIcons.trash,
                    variant: JButtonVariant.danger,
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    context.push('/jobs/${job.id}', extra: JobDetailArgs.fromJob(job));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final messenger = ScaffoldMessenger.of(context);
    showJSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete this listing?',
              style: tt.headlineSmall!.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text1,
              ),
            ),
            Gap(8.h),
            Text(
              "Applicants will no longer see it. This can't be undone "
              'from the app.',
              style: tt.bodyMedium!.copyWith(color: c.text3, height: 1.5),
            ),
            Gap(20.h),
            Row(
              children: [
                Expanded(
                  child: JButton(
                    label: 'CANCEL',
                    variant: JButtonVariant.secondary,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                Gap(10.w),
                Expanded(
                  child: JButton(
                    label: 'DELETE',
                    icon: AppIcons.trash,
                    variant: JButtonVariant.danger,
                    onPressed: () async {
                      final ok = await ref
                          .read(jobsControllerProvider.notifier)
                          .deleteJob(job.id);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      ref.invalidate(builderListingsProvider);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            ok ? 'Listing deleted.' : 'Delete failed.',
                          ),
                          backgroundColor: ok ? c.surfaceRaised : c.urgent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(JColors c, JobStatus s) => switch (s) {
    JobStatus.open => c.verified,
    JobStatus.filled => c.action,
    JobStatus.cancelled => c.urgent,
    JobStatus.closed || JobStatus.draft => c.text3,
  };

  static String _relPosted(Job job) {
    final ref = job.publishedAt ?? job.createdAt;
    final d = DateTime.now().difference(ref);
    if (d.inDays >= 1) return '${d.inDays}d ago';
    if (d.inHours >= 1) return '${d.inHours}h ago';
    if (d.inMinutes >= 1) return '${d.inMinutes}m ago';
    return 'just now';
  }
}

class _ListingsSkeleton extends StatelessWidget {
  const _ListingsSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return JSkeletonList(
      enabled: true,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(20.w, AppSpacing.sm.h, 20.w, 0),
        itemCount: 4,
        separatorBuilder: (_, _) => Gap(10.h),
        itemBuilder: (_, _) => Container(
          height: 150.h,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            border: Border.all(color: c.border),
          ),
        ),
      ),
    );
  }
}

class _ListingsEmpty extends StatelessWidget {
  const _ListingsEmpty({required this.tab});

  final _Tab tab;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final isAll = tab == _Tab.all;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.briefcase, size: AppIconSize.hero.r, color: c.text3),
            Gap(AppSpacing.md.h),
            Text(
              isAll ? 'NO LISTINGS YET.' : 'NOTHING HERE.',
              style: tt.headlineSmall!.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text1,
              ),
            ),
            Gap(AppSpacing.sm.h),
            Text(
              isAll
                  ? 'Post a job to start hiring tradies.'
                  : 'No listings in this status.',
              style: tt.bodyLarge!.copyWith(color: c.text3, height: 1.5),
              textAlign: TextAlign.center,
            ),
            if (isAll) ...[
              Gap(AppSpacing.lg.h),
              JButton(
                label: 'POST A JOB',
                icon: AppIcons.addSquare,
                onPressed: () => context.push('/jobs/create'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
