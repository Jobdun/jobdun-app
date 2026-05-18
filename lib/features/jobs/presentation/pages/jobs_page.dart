import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../app/constants/app_constants.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/tappable_icon.dart';
import '../../../../app/theme/app_gradients.dart';
import '../../../../core/design/widgets/gv_chip.dart';
import '../../../../core/design/widgets/job_card.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../jobs/domain/entities/job.dart';
import '../../../jobs/domain/entities/job_filter.dart';
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

  static const _tradeCategories = [
    'Electrician',
    'Plumber',
    'Carpenter',
    'Concreter',
    'Painter',
  ];

  // ── Trade Find Jobs (T3) state ──
  final _pageCtrl = PagingController<int, Job>(firstPageKey: 0);
  final _selectedTrades = <String>{};
  String _searchText = '';
  double? _budgetMin;
  double? _budgetMax;
  DateTime? _startFrom;
  DateTime? _startTo;
  // Only newest is wired to real data; relevance/nearest are deferred
  // (ts_rank RPC / PostGIS) and shown disabled.
  final JobSort _sort = JobSort.newest;

  @override
  void initState() {
    super.initState();
    _pageCtrl.addPageRequestListener(_fetchTradePage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(jobsControllerProvider.notifier).loadFeed();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  bool get _isBuilderRole =>
      ref.read(authControllerProvider).role == UserRole.builder;

  JobFilter _tradeFilter() => JobFilter(
    tradeTypes: _selectedTrades.isEmpty ? null : _selectedTrades.toList(),
    searchQuery: _searchText.isEmpty ? null : _searchText,
    budgetMin: _budgetMin,
    budgetMax: _budgetMax,
    startFrom: _startFrom,
    startTo: _startTo,
    sort: _sort,
    pageSize: 20,
  );

  Future<void> _fetchTradePage(int pageKey) async {
    try {
      final filter = _tradeFilter();
      final items = await ref
          .read(jobsControllerProvider.notifier)
          .fetchPage(page: pageKey, filter: filter);
      if (items.length < filter.pageSize) {
        _pageCtrl.appendLastPage(items);
      } else {
        _pageCtrl.appendPage(items, pageKey + 1);
      }
    } catch (e) {
      _pageCtrl.error = e;
    }
  }

  void _resetTradeFilters() {
    setState(() {
      _selectedTrades.clear();
      _searchText = '';
      _searchCtrl.clear();
      _budgetMin = null;
      _budgetMax = null;
      _startFrom = null;
      _startTo = null;
    });
    _pageCtrl.refresh();
  }

  void _comingSoon(String what) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$what is coming soon')));
  }

  int get _activeFilterCount {
    var n = 0;
    if (_selectedTrades.isNotEmpty) n++;
    if (_budgetMin != null || _budgetMax != null) n++;
    if (_startFrom != null || _startTo != null) n++;
    return n;
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        categories: _tradeCategories,
        selectedTrades: _selectedTrades,
        budgetMin: _budgetMin,
        budgetMax: _budgetMax,
        startFrom: _startFrom,
        startTo: _startTo,
      ),
    );
    if (result == null) return;
    setState(() {
      _selectedTrades
        ..clear()
        ..addAll(result.trades);
      _budgetMin = result.budgetMin;
      _budgetMax = result.budgetMax;
      _startFrom = result.startFrom;
      _startTo = result.startTo;
    });
    _pageCtrl.refresh();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (_isBuilderRole) {
        ref.read(jobsControllerProvider.notifier).search(query);
      } else {
        _searchText = query;
        _pageCtrl.refresh();
      }
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
                                    size: AppIconSize.sm.r,
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
                        Icon(
                          Iconsax.search_normal,
                          size: AppIconSize.sm.r,
                          color: c.text3,
                        ),
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
                          TappableIcon(
                            icon: Iconsax.close_circle,
                            semanticLabel: 'Clear search',
                            glyphSize: AppIconSize.sm,
                            color: c.text3,
                            onTap: () {
                              _searchCtrl.clear();
                              ref
                                  .read(jobsControllerProvider.notifier)
                                  .search('');
                            },
                          ),
                      ],
                    ),
                  ),
                  Gap(12.h),
                  // ── Filter chips
                  if (isBuilder)
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
                    )
                  else ...[
                    SizedBox(
                      height: 44.h,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _tradeCategories.length,
                        separatorBuilder: (ctx, idx) => Gap(AppSpacing.sm.w),
                        itemBuilder: (context, i) {
                          final f = _tradeCategories[i];
                          final isActive = _selectedTrades.contains(f);
                          return GvChip(
                            label: f,
                            active: isActive,
                            onTap: () {
                              setState(() {
                                if (isActive) {
                                  _selectedTrades.remove(f);
                                } else {
                                  _selectedTrades.add(f);
                                }
                              });
                              _pageCtrl.refresh();
                            },
                          );
                        },
                      ),
                    ),
                    Gap(10.h),
                    Row(
                      children: [
                        _SortControl(
                          sort: _sort,
                          onNewest: () {},
                          onDisabled: _comingSoon,
                        ),
                        const Spacer(),
                        Semantics(
                          button: true,
                          label: 'Filters',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _openFilterSheet,
                            child: Container(
                              constraints: BoxConstraints(
                                minHeight: AppTouchTarget.min,
                              ),
                              alignment: Alignment.center,
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.md.w,
                              ),
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.btn.r,
                                ),
                                border: Border.all(color: c.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Iconsax.setting_4,
                                    size: AppIconSize.sm.r,
                                    color: c.text2,
                                  ),
                                  Gap(6.w),
                                  Text(
                                    _activeFilterCount == 0
                                        ? 'Filters'
                                        : 'Filters · $_activeFilterCount',
                                    style: tt.bodyMedium!.copyWith(
                                      color: c.text1,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
                    Icon(
                      Iconsax.warning_2,
                      size: AppIconSize.sm.r,
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
            if (isBuilder) ...[
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
            ] else
              Expanded(
                child: PagedListView<int, Job>.separated(
                  pagingController: _pageCtrl,
                  padding: EdgeInsets.fromLTRB(
                    20.w,
                    AppSpacing.md.h,
                    20.w,
                    AppSpacing.lg.h,
                  ),
                  separatorBuilder: (_, _) => Gap(9.h),
                  builderDelegate: PagedChildBuilderDelegate<Job>(
                    itemBuilder: (context, j, i) => JobCard(
                      title: j.title,
                      description: j.description,
                      rate: j.displayBudget,
                      startDate: j.startDate != null
                          ? StringUtils.fmtDate(j.startDate!)
                          : j.displayLocation,
                      distanceKm: 0.0,
                      isUrgent: j.urgency == JobUrgency.urgent,
                      onSave: () => _comingSoon('Saving jobs'),
                      onTap: () => context.push(
                        '/jobs/${j.id}',
                        extra: JobDetailArgs.fromJob(j),
                      ),
                    ),
                    noItemsFoundIndicatorBuilder: (_) => _TradeEmptyState(
                      hasFilter:
                          _activeFilterCount > 0 || _searchText.isNotEmpty,
                      onReset: _resetTradeFilters,
                    ),
                    firstPageErrorIndicatorBuilder: (_) =>
                        _PagingError(onRetry: _pageCtrl.refresh),
                    newPageErrorIndicatorBuilder: (_) =>
                        _PagingError(onRetry: _pageCtrl.retryLastFailedRequest),
                  ),
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
            Icon(
              Iconsax.search_normal,
              size: AppIconSize.xxl.r,
              color: c.text3,
            ),
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

// ── T3 Trade Find Jobs sub-widgets ─────────────────────────────────────────────

class _SortControl extends StatelessWidget {
  const _SortControl({
    required this.sort,
    required this.onNewest,
    required this.onDisabled,
  });

  final JobSort sort;
  final VoidCallback onNewest;
  final void Function(String label) onDisabled;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    Widget seg(String label, bool active, bool enabled, VoidCallback onTap) {
      return Semantics(
        button: true,
        enabled: enabled,
        selected: active,
        label: enabled ? label : '$label, coming soon',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: AppTouchTarget.min),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w),
            child: Text(
              label,
              style: tt.bodyMedium!.copyWith(
                color: !enabled ? c.text3 : (active ? c.action : c.text2),
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        seg('Newest', sort == JobSort.newest, true, onNewest),
        seg('Relevance', false, false, () => onDisabled('Relevance sort')),
        seg('Nearest', false, false, () => onDisabled('Nearest sort')),
      ],
    );
  }
}

class _TradeEmptyState extends StatelessWidget {
  const _TradeEmptyState({required this.hasFilter, required this.onReset});

  final bool hasFilter;
  final VoidCallback onReset;

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
            Icon(
              Iconsax.search_normal,
              size: AppIconSize.xxl.r,
              color: c.text3,
            ),
            Gap(AppSpacing.md.h),
            Text(
              hasFilter ? 'NO JOBS MATCH YOUR FILTERS' : 'NO OPEN JOBS',
              style: tt.headlineSmall!.copyWith(
                fontSize: 22.sp,
                color: c.text1,
              ),
              textAlign: TextAlign.center,
            ),
            Gap(AppSpacing.sm.h),
            Text(
              hasFilter
                  ? 'Try widening distance or clearing filters.'
                  : 'Check back soon — new jobs are posted daily.',
              style: tt.bodyLarge!.copyWith(color: c.text3),
              textAlign: TextAlign.center,
            ),
            if (hasFilter) ...[
              Gap(AppSpacing.lg.h),
              Semantics(
                button: true,
                label: 'Reset filters',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onReset,
                  child: Container(
                    constraints: BoxConstraints(minHeight: AppTouchTarget.min),
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
                    decoration: BoxDecoration(
                      color: c.action,
                      borderRadius: BorderRadius.circular(AppRadius.btn.r),
                    ),
                    child: Text(
                      'RESET FILTERS',
                      style: tt.labelLarge!.copyWith(color: c.onAction),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PagingError extends StatelessWidget {
  const _PagingError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.warning_2, size: AppIconSize.xl.r, color: c.text3),
            Gap(AppSpacing.md.h),
            Text(
              "Couldn't load jobs.",
              style: tt.bodyLarge!.copyWith(color: c.text1),
            ),
            Gap(AppSpacing.md.h),
            Semantics(
              button: true,
              label: 'Retry',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRetry,
                child: Container(
                  constraints: BoxConstraints(minHeight: AppTouchTarget.min),
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppRadius.btn.r),
                    border: Border.all(color: c.border),
                  ),
                  child: Text(
                    'RETRY',
                    style: tt.labelLarge!.copyWith(color: c.text1),
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

class _FilterResult {
  const _FilterResult({
    required this.trades,
    this.budgetMin,
    this.budgetMax,
    this.startFrom,
    this.startTo,
  });

  final Set<String> trades;
  final double? budgetMin;
  final double? budgetMax;
  final DateTime? startFrom;
  final DateTime? startTo;
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.categories,
    required this.selectedTrades,
    this.budgetMin,
    this.budgetMax,
    this.startFrom,
    this.startTo,
  });

  final List<String> categories;
  final Set<String> selectedTrades;
  final double? budgetMin;
  final double? budgetMax;
  final DateTime? startFrom;
  final DateTime? startTo;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final Set<String> _trades = {...widget.selectedTrades};
  late final TextEditingController _minCtrl = TextEditingController(
    text: widget.budgetMin?.toStringAsFixed(0) ?? '',
  );
  late final TextEditingController _maxCtrl = TextEditingController(
    text: widget.budgetMax?.toStringAsFixed(0) ?? '',
  );
  late DateTime? _from = widget.startFrom;
  late DateTime? _to = widget.startTo;

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => isFrom ? _from = picked : _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    String dLabel(DateTime? d) => d == null ? 'Any' : StringUtils.fmtDate(d);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      padding: EdgeInsets.fromLTRB(
        20.w,
        16.h,
        20.w,
        MediaQuery.of(context).viewInsets.bottom + 20.h,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FILTERS',
              style: tt.labelSmall!.copyWith(
                letterSpacing: 0.12 * 11,
                color: c.text3,
              ),
            ),
            Gap(14.h),
            Text(
              'Trade categories',
              style: tt.bodyLarge!.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w600,
              ),
            ),
            Gap(10.h),
            Wrap(
              spacing: AppSpacing.sm.w,
              runSpacing: AppSpacing.sm.h,
              children: widget.categories.map((cat) {
                final on = _trades.contains(cat);
                return GvChip(
                  label: cat,
                  active: on,
                  onTap: () => setState(
                    () => on ? _trades.remove(cat) : _trades.add(cat),
                  ),
                );
              }).toList(),
            ),
            Gap(18.h),
            Text(
              'Budget range (\$)',
              style: tt.bodyLarge!.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w600,
              ),
            ),
            Gap(10.h),
            Row(
              children: [
                Expanded(
                  child: _NumField(controller: _minCtrl, hint: 'Min'),
                ),
                Gap(12.w),
                Expanded(
                  child: _NumField(controller: _maxCtrl, hint: 'Max'),
                ),
              ],
            ),
            Gap(18.h),
            Text(
              'Start window',
              style: tt.bodyLarge!.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w600,
              ),
            ),
            Gap(10.h),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'From: ${dLabel(_from)}',
                    onTap: () => _pickDate(true),
                  ),
                ),
                Gap(12.w),
                Expanded(
                  child: _DateField(
                    label: 'To: ${dLabel(_to)}',
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            Gap(18.h),
            // Distance is deferred (PostGIS + device location) — shown but
            // disabled so the design intent is visible without faking it.
            Opacity(
              opacity: 0.5,
              child: Row(
                children: [
                  Icon(
                    Iconsax.location,
                    size: AppIconSize.sm.r,
                    color: c.text3,
                  ),
                  Gap(8.w),
                  Text(
                    'Distance — coming soon',
                    style: tt.bodyMedium!.copyWith(color: c.text3),
                  ),
                ],
              ),
            ),
            Gap(22.h),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Clear filters',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(
                        context,
                        const _FilterResult(trades: {}),
                      ),
                      child: Container(
                        constraints: BoxConstraints(
                          minHeight: AppTouchTarget.min,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(AppRadius.btn.r),
                          border: Border.all(color: c.border),
                        ),
                        child: Text(
                          'CLEAR',
                          style: tt.labelLarge!.copyWith(color: c.text1),
                        ),
                      ),
                    ),
                  ),
                ),
                Gap(12.w),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Apply filters',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final mn = double.tryParse(_minCtrl.text.trim());
                        final mx = double.tryParse(_maxCtrl.text.trim());
                        Navigator.pop(
                          context,
                          _FilterResult(
                            trades: _trades,
                            budgetMin: mn,
                            budgetMax: mx,
                            startFrom: _from,
                            startTo: _to,
                          ),
                        );
                      },
                      child: Container(
                        constraints: BoxConstraints(
                          minHeight: AppTouchTarget.min,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.action,
                          borderRadius: BorderRadius.circular(AppRadius.btn.r),
                        ),
                        child: Text(
                          'APPLY',
                          style: tt.labelLarge!.copyWith(color: c.onAction),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      height: 44.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(AppRadius.input.r),
        border: Border.all(color: c.border),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: tt.bodyMedium!.copyWith(color: c.text1),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: tt.bodyMedium!.copyWith(color: c.text3),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44.h,
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(AppRadius.input.r),
            border: Border.all(color: c.border),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.bodyMedium!.copyWith(color: c.text1),
          ),
        ),
      ),
    );
  }
}
