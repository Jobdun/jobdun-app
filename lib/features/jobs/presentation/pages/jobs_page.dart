import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/gv_chip.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/design/widgets/job_card.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../jobs/domain/entities/job.dart';
import '../providers/jobs_provider.dart';
import 'job_detail_page.dart';

class JobsPage extends ConsumerStatefulWidget {
  const JobsPage({super.key});

  @override
  ConsumerState<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends ConsumerState<JobsPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  // Local UI-only flag — true when the SAVED chip is active, which swaps
  // the PagedListView out for a one-shot list of the user's saved jobs.
  // Distinct from the JobFilter (which only carries server-query filters)
  // so the chip can show its active state without polluting feed loads.
  bool _viewingSaved = false;

  static const _tradeFilters = [
    'All',
    'Electrician',
    'Plumber',
    'Carpenter',
    'Concreter',
    'Painter',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(jobsControllerProvider.notifier).loadFeed();
      // Tradies use the SAVED tab; builders never see it. Loading the IDs
      // unconditionally keeps the swipe label (SAVE vs UNSAVE) accurate
      // even for builders who hit /jobs in dev or by deep-link.
      ref.read(jobsControllerProvider.notifier).loadInteractionIds();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) ref.read(jobsControllerProvider.notifier).search(query);
    });
  }

  void _toggleSavedView() {
    final next = !_viewingSaved;
    setState(() => _viewingSaved = next);
    if (next) {
      ref.read(jobsControllerProvider.notifier).loadSavedJobs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final jobsState = ref.watch(jobsControllerProvider);
    // .select() — the JOBS page only branches on role; rebuilding here for
    // every auth-loading / email / pendingVerification flicker is wasted.
    final isBuilder = ref.watch(
      authControllerProvider.select((s) => s.role == UserRole.builder),
    );
    final activeFilter = jobsState.filter?.tradeType;
    // Observing the paging controller via ref.read so this widget rebuilds
    // for filter/search changes (which run through it) without listening
    // to every page append individually — the PagedListView below handles
    // its own incremental rebuilds.
    final pagingController = ref
        .read(jobsControllerProvider.notifier)
        .pagingController;
    final count = pagingController.itemList?.length ?? 0;
    final hasMorePages = pagingController.nextPageKey != null;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header
            Container(
              color: c.card,
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    eyebrow: isBuilder ? 'POSTED JOBS' : 'FIND WORK',
                    title: isBuilder ? 'Your listings' : 'Open near you',
                    trailing: isBuilder
                        ? SizedBox(
                            width: 130.w,
                            child: JButton(
                              label: 'POST JOB',
                              icon: AppIcons.add,
                              size: JButtonSize.compact,
                              onPressed: () => context.push('/jobs/create'),
                            ),
                          )
                        : null,
                  ),
                  Gap(12.h),
                  // Search bar — uses the theme's InputDecorationTheme directly
                  // so the focus border picks up c.action like every other input.
                  // design-system-ok: no FieldLabel above — search bars don't need one.
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    style: tt.bodyMedium!.copyWith(color: c.text1),
                    decoration: InputDecoration(
                      hintText: 'Search trades, skills, suburbs…',
                      prefixIcon: Icon(
                        AppIcons.search,
                        size: 16.r,
                        color: c.text3,
                      ),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(
                                AppIcons.closeCircle,
                                size: 16.r,
                                color: c.text3,
                              ),
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchCtrl.clear();
                                ref
                                    .read(jobsControllerProvider.notifier)
                                    .search('');
                              },
                            ),
                      isDense: true,
                    ),
                  ),
                  Gap(12.h),
                  // ── Filter chips
                  // Tradies get a SAVED chip in front of the trade filters
                  // that switches the body to their saved jobs list.
                  // Builders only see trade filters — they don't save jobs.
                  SizedBox(
                    height: 44.h,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: (isBuilder ? 0 : 1) + _tradeFilters.length,
                      separatorBuilder: (ctx, idx) => Gap(AppSpacing.sm.w),
                      itemBuilder: (context, i) {
                        if (!isBuilder && i == 0) {
                          return GvChip(
                            label: 'SAVED',
                            active: _viewingSaved,
                            onTap: () => _toggleSavedView(),
                          );
                        }
                        final f = _tradeFilters[i - (isBuilder ? 0 : 1)];
                        final isActive =
                            !_viewingSaved &&
                            (f == 'All'
                                ? activeFilter == null
                                : activeFilter == f);
                        return GvChip(
                          label: f,
                          active: isActive,
                          onTap: () {
                            if (_viewingSaved) {
                              setState(() => _viewingSaved = false);
                            }
                            ref
                                .read(jobsControllerProvider.notifier)
                                .applyFilter(f == 'All' ? null : f);
                          },
                        );
                      },
                    ),
                  ),
                  Gap(12.h),
                  Divider(height: 1, color: c.border),
                ],
              ),
            ),
            // ── Error banner
            if (jobsState.error != null)
              Container(
                width: double.infinity,
                color: c.urgentBg,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                child: Row(
                  children: [
                    Icon(AppIcons.warning, size: 16.r, color: c.urgentTx),
                    Gap(8.w),
                    Expanded(
                      child: Text(
                        jobsState.error!,
                        style: tt.bodyMedium!.copyWith(color: c.urgentTx),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Retry loading jobs',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            ref.read(jobsControllerProvider.notifier).refresh(),
                        child: SizedBox(
                          height: 44.h,
                          child: Center(
                            child: Text(
                              'Retry',
                              style: tt.bodyMedium!.copyWith(
                                color: c.urgentTx,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // ── Results count. "X+ jobs found" while more pages remain so
            // the number never looks misleadingly small during scroll-load.
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 4.h),
              child: Text(
                _viewingSaved
                    ? '${jobsState.savedJobs.length} saved'
                    : '$count${hasMorePages && count > 0 ? '+' : ''} '
                          '${count == 1 ? 'job' : 'jobs'} found',
                style: tt.labelMedium!.copyWith(
                  fontWeight: FontWeight.w400,
                  color: c.text3,
                ),
              ),
            ),
            // ── Job list
            Expanded(
              child: _viewingSaved
                  ? _SavedJobsList(
                      jobs: jobsState.savedJobs,
                      isLoading: jobsState.isLoadingSaved,
                      onUnsave: (jobId) => ref
                          .read(jobsControllerProvider.notifier)
                          .toggleSaveJob(jobId),
                      onBrowse: () => _toggleSavedView(),
                    )
                  : RefreshIndicator(
                      color: c.action,
                      backgroundColor: c.surface,
                      onRefresh: () async => pagingController.refresh(),
                      child: PagedListView<int, Job>.separated(
                        pagingController: pagingController,
                        padding: EdgeInsets.fromLTRB(
                          20.w,
                          AppSpacing.sm.h,
                          20.w,
                          AppSpacing.lg.h,
                        ),
                        separatorBuilder: (_, _) => Gap(9.h),
                        builderDelegate: PagedChildBuilderDelegate<Job>(
                          itemBuilder: (context, j, i) {
                            final card = JobCard(
                              title: j.title,
                              description: j.description,
                              rate: j.displayBudget,
                              startDate: j.startDate != null
                                  ? StringUtils.fmtDate(j.startDate!)
                                  : j.displayLocation,
                              distanceKm: 0.0,
                              isUrgent: j.urgency == JobUrgency.urgent,
                              onTap: () => context.push(
                                '/jobs/${j.id}',
                                extra: JobDetailArgs.fromJob(j),
                              ),
                            );
                            // Builders don't save or hide their own listings — RLS
                            // would block writes anyway, and the swipe affordances
                            // would just be noise. Tradies get the full slidable.
                            if (isBuilder) return card;
                            final isSaved = jobsState.savedJobIds.contains(
                              j.id,
                            );
                            return Slidable(
                              key: ValueKey('job-${j.id}'),
                              startActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                extentRatio: 0.28,
                                children: [
                                  SlidableAction(
                                    onPressed: (_) {
                                      HapticFeedback.lightImpact();
                                      ref
                                          .read(jobsControllerProvider.notifier)
                                          .hideJob(j.id);
                                    },
                                    backgroundColor: c.surfaceRaised,
                                    foregroundColor: c.text1,
                                    icon: AppIcons.eyeClosed,
                                    label: 'HIDE',
                                    autoClose: true,
                                  ),
                                ],
                              ),
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                extentRatio: 0.28,
                                children: [
                                  SlidableAction(
                                    onPressed: (_) {
                                      HapticFeedback.lightImpact();
                                      ref
                                          .read(jobsControllerProvider.notifier)
                                          .toggleSaveJob(j.id);
                                    },
                                    backgroundColor: c.action,
                                    foregroundColor: c.onAction,
                                    icon: isSaved
                                        ? AppIcons.successCircle
                                        : AppIcons.star,
                                    label: isSaved ? 'SAVED' : 'SAVE',
                                    autoClose: true,
                                  ),
                                ],
                              ),
                              child: card,
                            );
                          },
                          firstPageProgressIndicatorBuilder: (_) =>
                              const _FirstPageSkeleton(),
                          newPageProgressIndicatorBuilder: (_) => Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            child: Center(
                              child: SizedBox(
                                width: 22.r,
                                height: 22.r,
                                child: CircularProgressIndicator(
                                  color: c.action,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                          noItemsFoundIndicatorBuilder: (_) => _EmptyState(
                            hasFilter:
                                activeFilter != null ||
                                _searchCtrl.text.isNotEmpty,
                          ),
                          firstPageErrorIndicatorBuilder: (_) => _PageError(
                            message:
                                pagingController.error?.toString() ?? 'Error',
                            onRetry: () => pagingController.refresh(),
                          ),
                          newPageErrorIndicatorBuilder: (_) => _PageError(
                            message:
                                pagingController.error?.toString() ?? 'Error',
                            onRetry: () =>
                                pagingController.retryLastFailedRequest(),
                          ),
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

// First-page skeleton. Five placeholder JobCards inside JSkeletonList so the
// initial PagedListView load shows real-shaped shimmer instead of a spinner.
class _FirstPageSkeleton extends StatelessWidget {
  const _FirstPageSkeleton();

  @override
  Widget build(BuildContext context) {
    return JSkeletonList(
      enabled: true,
      child: ListView.separated(
        // Embedded inside a PagedListView slot — disable its own scroll so
        // the outer scrollable owns the gesture.
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: 5,
        separatorBuilder: (_, _) => Gap(9.h),
        itemBuilder: (_, _) => const _JobCardPlaceholder(),
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
            Icon(AppIcons.warning, size: 32.r, color: c.urgent),
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
              Icon(AppIcons.star, size: 48.r, color: c.text3),
              Gap(AppSpacing.md.h),
              Text(
                'NO SAVED JOBS.',
                style: tt.headlineSmall!.copyWith(
                  fontSize: 22.sp,
                  color: c.text1,
                ),
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
            distanceKm: 0.0,
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
            Icon(AppIcons.search, size: 48.r, color: c.text3),
            Gap(AppSpacing.md.h),
            Text(
              headline,
              style: tt.headlineSmall!.copyWith(
                fontSize: 22.sp,
                color: c.text1,
              ),
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
