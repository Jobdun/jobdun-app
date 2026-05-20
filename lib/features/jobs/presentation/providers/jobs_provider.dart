import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../core/config/supabase_config.dart';
import '../../data/datasources/job_remote_datasource.dart';
import '../../data/repositories/job_repository_impl.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/job_filter.dart';
import '../../domain/repositories/job_repository.dart';

final _jobDatasourceProvider = Provider<JobRemoteDataSource>(
  (ref) => JobRemoteDataSourceImpl(SupabaseConfig.client),
);

final _jobRepositoryProvider = Provider<JobRepository>(
  (ref) => JobRepositoryImpl(ref.read(_jobDatasourceProvider)),
);

final jobsControllerProvider = NotifierProvider<JobsController, JobsState>(
  JobsController.new,
);

/// Owns the jobs feed.
///
/// Holds two views of the same data so home + jobs screens can share one
/// source of truth:
///
/// - [state.jobs] — the latest **first page** of results. Read by the home
///   feed mini-list (`take(3)`) and the map markers. Always reflects the
///   active filter.
/// - [pagingController] — the **full paginated** stream of results. Read by
///   `jobs_page` through a [PagedListView]; back-fills as the user scrolls.
///
/// Filter and search mutations update `state.filter` then call
/// `pagingController.refresh()` so both views snap to the new query.
class JobsController extends Notifier<JobsState> {
  late JobRepository _repo;
  StreamSubscription<List<Job>>? _builderJobsSub;
  PagingController<int, Job>? _pagingController;

  /// Page size for `PagedListView` requests. Twenty rows hit roughly two
  /// viewport heights of `JobCard`s on a phone, which keeps the scroll
  /// feeling responsive without bursting through the user's first
  /// pagination boundary on initial load.
  static const _pageSize = 20;

  /// Lazy `PagingController`. Held lazily so the home screen — which never
  /// renders a `PagedListView` — doesn't pay the listener registration
  /// cost. `jobs_page` triggers init by reading this getter once on build.
  PagingController<int, Job> get pagingController {
    final existing = _pagingController;
    if (existing != null) return existing;
    final controller = PagingController<int, Job>(firstPageKey: 0);
    controller.addPageRequestListener(_fetchPage);
    _pagingController = controller;
    return controller;
  }

  @override
  JobsState build() {
    _repo = ref.read(_jobRepositoryProvider);
    ref.onDispose(() {
      _builderJobsSub?.cancel();
      _pagingController?.dispose();
    });
    return const JobsState();
  }

  Future<void> _fetchPage(int pageKey) async {
    final result = await _repo.getJobs(
      filter: state.filter,
      limit: _pageSize,
      offset: pageKey * _pageSize,
    );
    result.fold((f) => _pagingController?.error = f.message, (jobs) {
      // Mirror the first page into `state.jobs` so the home mini-feed and
      // map markers stay current without subscribing to the paging
      // controller themselves.
      if (pageKey == 0) {
        state = state.copyWith(isLoading: false, jobs: jobs);
      }
      final isLast = jobs.length < _pageSize;
      if (isLast) {
        _pagingController?.appendLastPage(jobs);
      } else {
        _pagingController?.appendPage(jobs, pageKey + 1);
      }
    });
  }

  /// First-page fetch entry point. Routes through `pagingController` when
  /// it's been observed (i.e., the jobs page is mounted) so both views
  /// stay in sync. Falls back to a one-shot fetch when not — keeps the
  /// home mini-feed working on cold start before the user visits `/jobs`.
  Future<void> loadFeed() async {
    final paging = _pagingController;
    if (paging != null) {
      paging.refresh();
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repo.getJobs(filter: state.filter, limit: _pageSize);
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (jobs) => state = state.copyWith(isLoading: false, jobs: jobs),
    );
  }

  Future<void> applyFilter(String? tradeType) async {
    final newFilter = tradeType == null
        ? null
        : JobFilter(
            tradeType: tradeType,
            status: state.filter?.status,
            searchQuery: state.filter?.searchQuery,
          );
    state = state.copyWith(filter: newFilter, clearFilter: newFilter == null);
    await loadFeed();
  }

  Future<void> search(String query) async {
    final newFilter = JobFilter(
      tradeType: state.filter?.tradeType,
      status: state.filter?.status,
      searchQuery: query.isEmpty ? null : query,
    );
    if (newFilter.isEmpty) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(filter: newFilter);
    }
    await loadFeed();
  }

  Future<void> refresh() => loadFeed();

  void clearFilter() {
    state = state.copyWith(clearFilter: true);
    loadFeed();
  }

  void watchBuilderJobs(String builderId) {
    _builderJobsSub?.cancel();
    _builderJobsSub = _repo
        .watchBuilderJobs(builderId)
        .listen(
          (jobs) => state = state.copyWith(jobs: jobs),
          onError: (Object e) => state = state.copyWith(error: e.toString()),
        );
  }
}

class JobsState {
  const JobsState({
    this.jobs = const [],
    this.filter,
    this.isLoading = false,
    this.error,
  });

  final List<Job> jobs;
  final JobFilter? filter;
  final bool isLoading;
  final String? error;

  JobsState copyWith({
    List<Job>? jobs,
    JobFilter? filter,
    bool clearFilter = false,
    bool? isLoading,
    String? error,
  }) => JobsState(
    jobs: jobs ?? this.jobs,
    filter: clearFilter ? null : (filter ?? this.filter),
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}
