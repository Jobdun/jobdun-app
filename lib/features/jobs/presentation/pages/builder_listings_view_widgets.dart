part of 'builder_listings_view.dart';

// Listing card + skeleton / empty states for BuilderListingsView, split into a
// part file so the page stays under the 500 LOC ceiling. No behaviour change.

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
      onTap: () => _openApplicants(context),
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
                Gap(4.w),
                // Overflow actions. Opaque hit-test so a tap here opens the
                // sheet rather than bubbling to the card tap (which views).
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showActions(context, ref),
                  child: Padding(
                    padding: EdgeInsets.all(6.r),
                    child: Icon(
                      AppIcons.more,
                      size: AppIconSize.md.r,
                      color: c.text3,
                    ),
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
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    context.push('/jobs/${job.id}', extra: JobDetailArgs.fromJob(job));
  }

  // Builder taps a listing → applicants for that job (layout A). The job
  // summary rides along so the screen renders before the list loads.
  void _openApplicants(BuildContext context) {
    context.push(
      '/jobs/${job.id}/applicants',
      extra: JobApplicantsArgs(
        jobId: job.id,
        title: job.title,
        tradeType: job.tradeTypeRequired,
        locationLabel: '${job.suburb}, ${job.state}',
        payLabel: job.displayBudget,
        statusLabel: job.status.label.toUpperCase(),
      ),
    );
  }

  /// Overflow sheet for a listing. Lists only the actions wired today (view
  /// applicants + delete); Edit / Mark filled / Duplicate slot in here as they
  /// are built.
  void _showActions(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    showJSheet<void>(
      context: context,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.card.r),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Gap(AppSpacing.sm.h),
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Gap(AppSpacing.sm.h),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.pop(ctx);
                  _openDetail(context);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg.w,
                    vertical: 14.h,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.info,
                        size: AppIconSize.md.r,
                        color: c.text2,
                      ),
                      Gap(AppSpacing.md.w),
                      Text(
                        'Job details',
                        style: tt.bodyLarge!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: c.text1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: c.border),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context, ref);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg.w,
                    vertical: 14.h,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.trash,
                        size: AppIconSize.md.r,
                        color: c.urgent,
                      ),
                      Gap(AppSpacing.md.w),
                      Text(
                        'Delete listing',
                        style: tt.bodyLarge!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: c.urgent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Gap(AppSpacing.sm.h),
            ],
          ),
        ),
      ),
    );
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
                      // Bust every builder aggregate (not just listings) so the
                      // home/profile counts drop the deleted job too.
                      invalidateBuilderJobAggregates(ref);
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
