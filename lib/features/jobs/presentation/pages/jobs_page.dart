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
import 'builder_listings_view.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../jobs/domain/entities/job.dart';
import '../../../verification/presentation/widgets/verification_nudge_banner.dart';
import '../providers/jobs_provider.dart';
import '../widgets/jobs_search_place_chip.dart';
import 'job_detail_page.dart';

part 'jobs_page_widgets.dart';

class JobsPage extends ConsumerStatefulWidget {
  const JobsPage({super.key});

  @override
  ConsumerState<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends ConsumerState<JobsPage> {
  final _searchCtrl = TextEditingController();
  // Mirrored search query so JobsSearchPlaceChip rebuilds — _searchCtrl.text
  // doesn't drive a rebuild on its own.
  String _currentQuery = '';
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
      // Builders get the dedicated management view (BuilderListingsView) which
      // owns its own data — only the tradie browse feed loads here.
      final isBuilder =
          ref.read(authControllerProvider).role == UserRole.builder;
      if (isBuilder) return;
      final notifier = ref.read(jobsControllerProvider.notifier);
      notifier.loadFeed();
      notifier.loadInteractionIds();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query != _currentQuery) {
      setState(() => _currentQuery = query);
    }
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
    // Guest mode (App Review 5.1.1(v)) — this same page also serves the
    // public /browse route. Guests browse and read freely; the account-based
    // affordances (SAVED chip, save/hide swipes, verification nudge) hide,
    // and a LOG IN action rides the header instead.
    final isAuthed = ref.watch(
      authControllerProvider.select((s) => s.isAuthenticated),
    );
    // Builders get the dedicated listings-management view; tradies get the
    // browse feed below.
    if (isBuilder) return const BuilderListingsView();
    final showSavedChip = isAuthed;
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
                    eyebrow: isAuthed ? null : 'JOBDUN',
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
                        : !isAuthed
                        ? SizedBox(
                            width: 110.w,
                            child: JButton(
                              label: 'LOG IN',
                              size: JButtonSize.compact,
                              onPressed: () => context.go('/login'),
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
                        size: AppIconSize.inline.r,
                        color: c.text3,
                      ),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(
                                AppIcons.closeCircle,
                                size: AppIconSize.inline.r,
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
                  JobsSearchPlaceChip(
                    query: _currentQuery,
                    onTap: (place) {
                      _searchCtrl.text = place.suburb;
                      _onSearchChanged(place.suburb);
                    },
                  ),
                  Gap(12.h),
                  // ── Filter chips
                  // Signed-in tradies get a SAVED chip in front of the trade
                  // filters that switches the body to their saved jobs list.
                  // Builders don't save jobs; guests have nothing saved.
                  SizedBox(
                    height: 44.h,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: (showSavedChip ? 1 : 0) + _tradeFilters.length,
                      separatorBuilder: (ctx, idx) => Gap(AppSpacing.sm.w),
                      itemBuilder: (context, i) {
                        if (showSavedChip && i == 0) {
                          return GvChip(
                            label: 'SAVED',
                            active: _viewingSaved,
                            onTap: () => _toggleSavedView(),
                          );
                        }
                        final f = _tradeFilters[i - (showSavedChip ? 1 : 0)];
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
                    Icon(
                      AppIcons.warning,
                      size: AppIconSize.inline.r,
                      color: c.urgentTx,
                    ),
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
            // ── Verification nudge banner (v2). Self-hides when already
            // fully verified or dismissed for this session. Account-based —
            // guests never see it.
            if (isAuthed) const VerificationNudgeBanner(),
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
                            // would just be noise. Guests get the plain card too:
                            // save/hide are account-based (5.1.1(v) keeps browsing
                            // free, not the bookmarking). Signed-in tradies get
                            // the full slidable.
                            if (isBuilder || !isAuthed) return card;
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
                          // Only a guest reaching the end of their capped
                          // preview sees the conversion nudge — a signed-in
                          // user hitting the real end of the feed sees
                          // nothing, same as before this feature existed.
                          noMoreItemsIndicatorBuilder: isAuthed
                              ? null
                              : (_) => const _GuestSignInTeaser(),
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
