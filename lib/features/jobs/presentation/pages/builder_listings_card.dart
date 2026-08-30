part of 'builder_listings_view.dart';

// The listing card and its delete-confirmation sheet, split out of
// `builder_listings_view_widgets.dart` to stay under the 500 LOC ceiling.

class _ListingCard extends ConsumerWidget {
  const _ListingCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final applicants = job.applicationCount;
    // Applicants read as a live signal only when there ARE some — orange ink
    // on a count of zero would promise attention the listing hasn't earned.
    final applicantColor = applicants > 0 ? c.actionInk : c.text1;

    // Figma `JobDun-Screens` → Manage Listings (node 87:5741): 16dp radius on
    // a hairline, 16dp padding and rhythm; status pill and applicant count
    // share the top row, the title sits alone, and the money/place/age line
    // lives under a rule.
    return GestureDetector(
      onTap: () => _openApplicants(context),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md.r),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Both ends shrink under pressure: a long status ("Cancelled")
            // beside "5 applicants" overflowed a 360dp card before this.
            Row(
              children: [
                Flexible(
                  child: StatusBadge(
                    variant: _statusVariant(job.status),
                    label: job.status.label,
                  ),
                ),
                const Spacer(),
                Icon(
                  AppIcons.applicantsOutline,
                  size: AppIconSize.micro.r,
                  color: applicantColor,
                ),
                Gap(AppSpacing.xs.w),
                Flexible(
                  child: Text(
                    applicants == 1 ? '1 applicant' : '$applicants applicants',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall!.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      color: applicantColor,
                    ),
                  ),
                ),
                Gap(AppSpacing.xs.w),
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
                      color: c.text1,
                    ),
                  ),
                ),
              ],
            ),
            Gap(AppSpacing.md.h),
            Text(
              job.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.titleMedium!.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: c.text1,
              ),
            ),
            Gap(AppSpacing.md.h),
            Container(height: 1, color: c.border),
            Gap(AppSpacing.md.h),
            Text(
              '${job.displayBudget} • ${job.suburb} • ${_relPosted(job)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall!.copyWith(
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
                height: 1.0,
                color: c.text3,
              ),
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
    final messenger = ScaffoldMessenger.of(context);
    showJSheet<void>(
      context: context,
      builder: (_) => _DeleteConfirmSheet(job: job, messenger: messenger),
    );
  }

  /// Maps a listing's status onto the shared status-pill vocabulary: open is
  /// a healthy live listing (green), filled is a terminal-but-good state
  /// (olive), closed/cancelled are dead (red). Draft has no pill colour of its
  /// own and borrows the neutral `pro` treatment.
  static BadgeVariant _statusVariant(JobStatus s) => switch (s) {
    JobStatus.open => BadgeVariant.verified,
    JobStatus.filled => BadgeVariant.warning,
    JobStatus.closed || JobStatus.cancelled => BadgeVariant.urgent,
    JobStatus.draft => BadgeVariant.pro,
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

/// Delete confirmation sheet. Stateful so the DELETE button carries an
/// in-flight guard — double-tapping used to double-pop and close the listings
/// page underneath (P6 companion fix, 2026-08-18 audit).
class _DeleteConfirmSheet extends ConsumerStatefulWidget {
  const _DeleteConfirmSheet({required this.job, required this.messenger});

  final Job job;
  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<_DeleteConfirmSheet> createState() =>
      _DeleteConfirmSheetState();
}

class _DeleteConfirmSheetState extends ConsumerState<_DeleteConfirmSheet> {
  bool _deleting = false;

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() => _deleting = true);
    final c = context.c;
    final ok = await ref
        .read(jobsControllerProvider.notifier)
        .deleteJob(widget.job.id);
    if (!mounted) return;
    // Bust every builder aggregate (not just listings) so the home/profile
    // counts drop the deleted job too.
    invalidateBuilderJobAggregates(ref);
    Navigator.pop(context);
    widget.messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Listing deleted.' : 'Delete failed.'),
        backgroundColor: ok ? c.surfaceRaised : c.urgent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Padding(
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
                  onPressed: _deleting ? null : () => Navigator.pop(context),
                ),
              ),
              Gap(10.w),
              Expanded(
                child: JButton(
                  label: 'DELETE',
                  icon: AppIcons.trash,
                  variant: JButtonVariant.danger,
                  isLoading: _deleting,
                  onPressed: _deleting ? null : _delete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
