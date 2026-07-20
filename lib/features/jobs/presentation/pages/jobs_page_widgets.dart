part of 'jobs_page.dart';

// Private list/state leaf widgets for the jobs feed, split into a `part` so
// `jobs_page.dart` stays under the file-size budget. They remain private,
// single-use helpers co-located with their only caller (the page state).

// First-page skeleton. Five placeholder JobCards inside JSkeletonList so the
// initial PagedListView load shows real-shaped shimmer instead of a spinner.
// Why: infinite_scroll_pagination puts this inside SliverFillRemaining
// (hasScrollBody: false), which needs an intrinsic-height child. A ListView
// is scrollable and has no intrinsic height — even with shrinkWrap — so it
// trips a "RenderBox was not laid out" / null-check chain during layout.
// A Column has well-defined intrinsics and renders identically here.
class _FirstPageSkeleton extends StatelessWidget {
  const _FirstPageSkeleton();

  @override
  Widget build(BuildContext context) {
    return JSkeletonList(
      enabled: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) Gap(9.h),
            const _JobCardPlaceholder(),
          ],
        ],
      ),
    );
  }
}

// Inline error indicator for first-page + new-page failures. Tap to retry.
class _PageError extends StatelessWidget {
  const _PageError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.warning,
              size: AppIconSize.feature.r,
              color: c.urgent,
            ),
            Gap(AppSpacing.md.h),
            Text(
              message,
              style: tt.bodyMedium!.copyWith(color: c.urgentTx),
              textAlign: TextAlign.center,
            ),
            Gap(AppSpacing.md.h),
            SizedBox(
              width: 160.w,
              child: JButton(
                label: 'RETRY',
                variant: JButtonVariant.secondary,
                onPressed: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// One-shot list of the user's saved jobs. Doesn't paginate — saved
// bookmarks are bounded for a typical user, and a separate cursor stream
// here would double the controller surface for marginal payoff. Each row
// supports a left swipe to UNSAVE (the SAVED chip implicitly stays
// active; the user can scroll the strip back if they want to leave the
// view).
class _SavedJobsList extends StatelessWidget {
  const _SavedJobsList({
    required this.jobs,
    required this.isLoading,
    required this.onUnsave,
    required this.onBrowse,
  });

  final List<Job> jobs;
  final bool isLoading;
  final void Function(String jobId) onUnsave;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    if (isLoading && jobs.isEmpty) {
      return const _FirstPageSkeleton();
    }
    if (jobs.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.star, size: AppIconSize.hero.r, color: c.text3),
              Gap(AppSpacing.md.h),
              Text(
                'NO SAVED JOBS.',
                style: tt.headlineSmall!.copyWith(color: c.text1),
              ),
              Gap(AppSpacing.sm.h),
              Text(
                'Swipe a job to the left to save it for later.',
                style: tt.bodyLarge!.copyWith(color: c.text3),
                textAlign: TextAlign.center,
              ),
              Gap(AppSpacing.lg.h),
              SizedBox(
                width: 200.w,
                child: JButton(label: 'BROWSE JOBS', onPressed: onBrowse),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        20.w,
        AppSpacing.sm.h,
        20.w,
        AppSpacing.lg.h,
      ),
      itemCount: jobs.length,
      separatorBuilder: (_, _) => Gap(9.h),
      itemBuilder: (context, i) {
        final j = jobs[i];
        return Slidable(
          key: ValueKey('saved-job-${j.id}'),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.28,
            children: [
              SlidableAction(
                onPressed: (_) {
                  HapticFeedback.lightImpact();
                  onUnsave(j.id);
                },
                backgroundColor: c.surfaceRaised,
                foregroundColor: c.text1,
                icon: AppIcons.closeBox,
                label: 'UNSAVE',
                autoClose: true,
              ),
            ],
          ),
          child: JobCard(
            title: j.title,
            description: j.description,
            rate: j.displayBudget,
            startDate: j.startDate != null
                ? StringUtils.fmtDate(j.startDate!)
                : j.displayLocation,
            distanceKm: null,
            isUrgent: j.urgency == JobUrgency.urgent,
            onTap: () =>
                context.push('/jobs/${j.id}', extra: JobDetailArgs.fromJob(j)),
          ),
        );
      },
    );
  }
}

// Loading-state stand-in. Real-shaped JobCard fed placeholder strings so
// Skeletonizer can mask it into shimmer blocks that match the loaded layout.
class _JobCardPlaceholder extends StatelessWidget {
  const _JobCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return JobCard(
      title: 'Loading job title placeholder',
      description:
          'Description line one placeholder text\nDescription line two placeholder text',
      rate: '\$\$\$/hr',
      startDate: 'Today',
      distanceKm: 0,
      isUrgent: false,
      onTap: () {},
    );
  }
}

// End-of-guest-feed conversion nudge (App Review 5.1.1(v): the guest preview
// is capped — see JobsController._guestPageSize). Shown once, right after
// the last card, via PagedChildBuilderDelegate.noMoreItemsIndicatorBuilder.
// Same tinted-orange nudge language as VerificationNudgeBanner (the
// authenticated-side equivalent on this same page), but framed as a
// standalone card since it's the terminal state of the list, not a banner
// squeezed above it. Copy stays honest regardless of current inventory size
// — "browse every open job" is true whether the real total is above or
// below the cap; "apply, save" is always exclusively account-based.
class _GuestSignInTeaser extends StatelessWidget {
  const _GuestSignInTeaser();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: c.actionBg,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.action.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.lock, size: AppIconSize.md.r, color: c.action),
              Gap(AppSpacing.sm.w),
              Expanded(
                child: Text(
                  'WANT TO SEE MORE?',
                  style: tt.titleLarge!.copyWith(color: c.text1),
                ),
              ),
            ],
          ),
          Gap(AppSpacing.sm.h),
          Text(
            'Create a free account to browse every open job, apply, and '
            'save the ones you like.',
            style: tt.bodyMedium!.copyWith(color: c.text2),
          ),
          Gap(AppSpacing.md.h),
          JButton(
            label: 'CREATE ACCOUNT',
            onPressed: () => context.go('/register'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.hasFilter});

  final bool hasFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final isBuilder = ref.watch(
      authControllerProvider.select((s) => s.role == UserRole.builder),
    );

    final headline = hasFilter
        ? 'NO JOBS FOUND.'
        : isBuilder
        ? 'NO LISTINGS YET.'
        : 'NO OPEN JOBS.';
    final body = hasFilter
        ? 'Try a different trade or clear your filters.'
        : isBuilder
        ? 'Post your first job to start receiving applications.'
        : 'Check back soon — new jobs are posted daily.';
    final ctaLabel = hasFilter
        ? 'CLEAR FILTERS'
        : isBuilder
        ? 'POST A JOB'
        : null;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.search, size: AppIconSize.hero.r, color: c.text3),
            Gap(AppSpacing.md.h),
            Text(
              headline,
              style: tt.headlineSmall!.copyWith(color: c.text1),
              textAlign: TextAlign.center,
            ),
            Gap(AppSpacing.sm.h),
            Text(
              body,
              style: tt.bodyLarge!.copyWith(color: c.text3),
              textAlign: TextAlign.center,
            ),
            if (ctaLabel != null) ...[
              Gap(AppSpacing.lg.h),
              SizedBox(
                width: 200.w,
                child: JButton(
                  label: ctaLabel,
                  onPressed: () {
                    if (hasFilter) {
                      ref
                          .read(jobsControllerProvider.notifier)
                          .applyFilter(null);
                      ref.read(jobsControllerProvider.notifier).search('');
                    } else {
                      context.push('/jobs/create');
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
