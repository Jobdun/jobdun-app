import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_gradients.dart';
import '../../../../core/design/widgets/gv_chip.dart';
import '../../../../core/design/widgets/job_card.dart';
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
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isBuilder ? 'POSTED JOBS' : 'FIND WORK',
                              style: tt.labelSmall!.copyWith(
                                letterSpacing: 0.12 * 11,
                                color: c.text3,
                              ),
                            ),
                            Gap(4.h),
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  AppGradients.brandFlame.createShader(bounds),
                              child: Text(
                                isBuilder ? 'Your listings' : 'Open near you',
                                style: tt.headlineSmall!.copyWith(
                                  fontSize: 28.sp,
                                  letterSpacing: 0.02 * 28,
                                  color: Colors
                                      .white, // intentional: ShaderMask requires white for gradient
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isBuilder)
                        Semantics(
                          button: true,
                          label: 'Post a new job',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => context.push('/jobs/create'),
                            child: Container(
                              height: 44.h,
                              padding: EdgeInsets.symmetric(horizontal: 14.w),
                              decoration: BoxDecoration(
                                color: c.action,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.btn.r,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Iconsax.add,
                                    size: 16.r,
                                    color: c.onAction,
                                  ),
                                  Gap(6.w),
                                  Text(
                                    'POST JOB',
                                    style: tt.bodyMedium!.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                      color: c.onAction,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Gap(12.h),
                  // ── Search bar
                  Container(
                    height: 40.h,
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(AppRadius.input.r),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Gap(14.w),
                        Icon(Iconsax.search_normal, size: 16.r, color: c.text3),
                        Gap(AppSpacing.sm.w),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: _onSearchChanged,
                            style: tt.bodyMedium!.copyWith(color: c.text1),
                            decoration: InputDecoration(
                              hintText: 'Search trades, skills, suburbs…',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_searchCtrl.text.isNotEmpty)
                          Semantics(
                            button: true,
                            label: 'Clear search',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                _searchCtrl.clear();
                                ref
                                    .read(jobsControllerProvider.notifier)
                                    .search('');
                              },
                              child: SizedBox(
                                width: 44.w,
                                height: 44.h,
                                child: Icon(
                                  Iconsax.close_circle,
                                  size: 16.r,
                                  color: c.text3,
                                ),
                              ),
                            ),
                          ),
                      ],
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
            // ── Loading bar
            if (isLoading)
              LinearProgressIndicator(
                color: c.action,
                backgroundColor: c.surface,
                minHeight: 2,
              ),
            // ── Error banner
            if (jobsState.error != null)
              Container(
                width: double.infinity,
                color: c.urgentBg,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                child: Row(
                  children: [
                    Icon(Iconsax.warning_2, size: 16.r, color: c.urgentTx),
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
              child: count == 0 && !isLoading
                  ? _EmptyState(
                      hasFilter:
                          activeFilter != null || _searchCtrl.text.isNotEmpty,
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        20.w,
                        AppSpacing.sm.h,
                        20.w,
                        AppSpacing.lg.h,
                      ),
                      itemCount: count,
                      separatorBuilder: (ctx, idx) => Gap(9.h),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});

  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.search_normal, size: 48.r, color: c.text3),
            Gap(AppSpacing.md.h),
            Text(
              hasFilter ? 'NO JOBS FOUND.' : 'NO OPEN JOBS.',
              style: tt.headlineSmall!.copyWith(
                fontSize: 22.sp,
                color: c.text1,
              ),
              textAlign: TextAlign.center,
            ),
            Gap(AppSpacing.sm.h),
            Text(
              hasFilter
                  ? 'Try a different trade or clear your filters.'
                  : 'Check back soon — new jobs are posted daily.',
              style: tt.bodyLarge!.copyWith(color: c.text3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
