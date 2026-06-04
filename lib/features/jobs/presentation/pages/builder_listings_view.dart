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
