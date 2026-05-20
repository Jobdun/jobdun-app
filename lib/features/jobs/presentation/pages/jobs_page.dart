import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/gv_chip.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/design/widgets/j_staggered_list.dart';
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

  static const _filters = [
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
      if (mounted) ref.read(jobsControllerProvider.notifier).loadFeed();
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

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final jobsState = ref.watch(jobsControllerProvider);
    final isBuilder =
        ref.watch(authControllerProvider).role == UserRole.builder;
    final activeFilter = jobsState.filter?.tradeType;
    final jobs = jobsState.jobs;
    final isLoading = jobsState.isLoading;

    final count = jobs.length;

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
                  SizedBox(
                    height: 44.h,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (ctx, idx) => Gap(AppSpacing.sm.w),
                      itemBuilder: (context, i) {
                        final f = _filters[i];
                        final isActive = f == 'All'
                            ? activeFilter == null
                            : activeFilter == f;
                        return GvChip(
                          label: f,
                          active: isActive,
                          onTap: () => ref
                              .read(jobsControllerProvider.notifier)
                              .applyFilter(f == 'All' ? null : f),
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
            // ── Results count
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 4.h),
              child: Text(
                '$count ${count == 1 ? 'job' : 'jobs'} found',
                style: tt.labelMedium!.copyWith(
                  fontWeight: FontWeight.w400,
                  color: c.text3,
                ),
              ),
            ),
            // ── Job list
            Expanded(
              child: isLoading && count == 0
                  ? JSkeletonList(
                      enabled: true,
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          20.w,
                          AppSpacing.sm.h,
                          20.w,
                          AppSpacing.lg.h,
                        ),
                        itemCount: 5,
                        separatorBuilder: (ctx, idx) => Gap(9.h),
                        itemBuilder: (context, i) =>
                            const _JobCardPlaceholder(),
                      ),
                    )
                  : count == 0
                  ? _EmptyState(
                      hasFilter:
                          activeFilter != null || _searchCtrl.text.isNotEmpty,
                    )
                  : JStaggeredList(
                      padding: EdgeInsets.fromLTRB(
                        20.w,
                        AppSpacing.sm.h,
                        20.w,
                        AppSpacing.lg.h,
                      ),
                      itemCount: count,
                      itemBuilder: (context, i) {
                        final j = jobs[i];
                        return JobCard(
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
                      },
                    ),
            ),
          ],
        ),
      ),
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
    final isBuilder =
        ref.watch(authControllerProvider).role == UserRole.builder;

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
