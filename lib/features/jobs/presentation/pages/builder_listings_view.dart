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
import '../../../../core/design/widgets/jobdun_logo.dart';
import '../../../../core/design/widgets/status_badge.dart';
import '../../../applications/presentation/pages/job_applicants_args.dart';
import '../../domain/entities/job.dart';
import '../providers/jobs_provider.dart';
import 'job_detail_page.dart';

part 'builder_listings_card.dart';
part 'builder_listings_view_widgets.dart';

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
    // P6, 2026-08-18 audit: keep any previously loaded value on a refresh
    // error; a failed FIRST load renders the error state below, never the
    // "NO LISTINGS YET" empty state.
    final all = async.value ?? const <Job>[];

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header — Figma `JobDun-Screens` → Manage Listings (node
            // 84:5306): mark, "Listings" in Inter Bold 24, and a compact
            // orange "Post a job" pill. The old MANAGE eyebrow is gone — the
            // bottom dock already says which tab this is.
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md.w,
                AppSpacing.sm.h,
                AppSpacing.md.w,
                AppSpacing.sm.h,
              ),
              child: Row(
                children: [
                  JobdunLogo(variant: LogoVariant.mark, height: 32.h),
                  Gap(AppSpacing.sm.w),
                  Expanded(
                    child: Text(
                      'Listings',
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: c.text1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Gap(AppSpacing.sm.w),
                  _PostJobButton(onTap: () => context.push('/jobs/create')),
                ],
              ),
            ),
            // ── Status tabs (node 87:5635): one bordered pill holding four
            // equal segments; the active one is the orange thumb.
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md.w,
                AppSpacing.sm.h,
                AppSpacing.md.w,
                AppSpacing.xs.h,
              ),
              child: Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(AppRadius.btn.r),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    for (final t in _Tab.values)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: _tab == t,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _tab = t),
                            child: Container(
                              height: 40.h,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _tab == t
                                    ? c.action
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.btn.r,
                                ),
                              ),
                              child: Text(
                                _tabLabel(t),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium!
                                    .copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.0,
                                      color: _tab == t ? c.onAction : c.text2,
                                    ),
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
                  // P6, 2026-08-18 audit: failed load → error + RETRY.
                  : async.hasError && all.isEmpty
                  ? _ListingsError(
                      onRetry: () => ref.invalidate(builderListingsProvider),
                    )
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
          AppSpacing.md.w,
          AppSpacing.sm.h,
          AppSpacing.md.w,
          AppSpacing.lg.h,
        ),
        itemCount: jobs.length,
        separatorBuilder: (_, _) => Gap(AppSpacing.md.h),
        itemBuilder: (_, i) => _ListingCard(job: jobs[i]),
      ),
    );
  }
}
