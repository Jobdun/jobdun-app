import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../core/config/supabase_config.dart';
import '../../data/datasources/job_interactions_datasource.dart';
import '../../data/datasources/job_remote_datasource.dart';
import '../../data/repositories/job_interactions_repository_impl.dart';
import '../../data/repositories/job_repository_impl.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/job_filter.dart';
import '../../domain/repositories/job_interactions_repository.dart';
import '../../domain/repositories/job_repository.dart';

final _jobDatasourceProvider = Provider<JobRemoteDataSource>(
  (ref) => JobRemoteDataSourceImpl(SupabaseConfig.client),
);

final _jobRepositoryProvider = Provider<JobRepository>(
  (ref) => JobRepositoryImpl(ref.read(_jobDatasourceProvider)),
);

final _jobInteractionsDatasourceProvider = Provider<JobInteractionsDataSource>(
  (ref) => JobInteractionsDataSourceImpl(SupabaseConfig.client),
);

final _jobInteractionsRepositoryProvider = Provider<JobInteractionsRepository>(
  (ref) => JobInteractionsRepositoryImpl(
    ref.read(_jobInteractionsDatasourceProvider),
  ),
);

final jobsControllerProvider = NotifierProvider<JobsController, JobsState>(
  JobsController.new,
);

/// Owns the jobs feed.
///
/// Three views of the same underlying data are exposed so home + jobs
/// screens share one source of truth:
///
/// - [state.jobs] — latest **first page** of the open-feed query. Read by
///   the home mini-list (`take(3)`) and the map markers.
/// - [pagingController] — full **paginated** open-feed stream. Read by
///   `jobs_page` through a [PagedListView]; back-fills as the user scrolls.
///   Hidden-job IDs are filtered out of each appended page.
/// - [state.savedJobs] — the user's **saved** list, fetched in one shot
///   when the SAVED filter is selected. Doesn't paginate (a typical
///   bookmark list is bounded).
///
/// Filter / search / save / hide mutations update state then call
/// `pagingController.refresh()` so all three views snap to the new query.
class JobsController extends Notifier<JobsState> {
  late JobRepository _repo;
  late JobInteractionsRepository _interactions;
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
    _interactions = ref.read(_jobInteractionsRepositoryProvider);
    ref.onDispose(() {
      _builderJobsSub?.cancel();
      _pagingController?.dispose();
    });
    return const JobsState();
  }

  /// Pull saved + hidden IDs from the server. Cheap (IDs only, no joins)
  /// and idempotent; call once at /jobs mount.
  Future<void> loadInteractionIds() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    final savedResult = await _interactions.getSavedJobIds(userId);
    final hiddenResult = await _interactions.getHiddenJobIds(userId);
    state = state.copyWith(
      savedJobIds: savedResult.fold((_) => const <String>{}, (ids) => ids),
      hiddenJobIds: hiddenResult.fold((_) => const <String>{}, (ids) => ids),
    );
  }

  Future<void> _fetchPage(int pageKey) async {
    final result = await _repo.getJobs(
      filter: state.filter,
      limit: _pageSize,
      offset: pageKey * _pageSize,
    );
    result.fold((f) => _pagingController?.error = f.message, (jobs) {
      // Filter out the rows the user has hidden. Done client-side so the
      // SQL stays simple at the cost of occasional short pages — fine
      // until a user accumulates dozens of hidden jobs, at which point we
      // move the filter to .not('id', 'in', ...) at the data source.
      final visible = state.hiddenJobIds.isEmpty
          ? jobs
          : jobs.where((j) => !state.hiddenJobIds.contains(j.id)).toList();

      // Mirror the first page into `state.jobs` so the home mini-feed and
      // map markers stay current without subscribing to the paging
      // controller themselves.
      if (pageKey == 0) {
        state = state.copyWith(isLoading: false, jobs: visible);
      }
      final isLast = jobs.length < _pageSize;
      if (isLast) {
        _pagingController?.appendLastPage(visible);
      } else {
        _pagingController?.appendPage(visible, pageKey + 1);
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
      (jobs) {
        final visible = state.hiddenJobIds.isEmpty
            ? jobs
            : jobs.where((j) => !state.hiddenJobIds.contains(j.id)).toList();
        state = state.copyWith(isLoading: false, jobs: visible);
      },
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

  /// Load the user's saved jobs in one shot. Stored on state so the SAVED
  /// filter view in `jobs_page` can render them without re-fetching.
  Future<void> loadSavedJobs() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    state = state.copyWith(isLoadingSaved: true);
    final result = await _interactions.getSavedJobs(userId);
    result.fold(
      (f) => state = state.copyWith(isLoadingSaved: false, error: f.message),
      (jobs) => state = state.copyWith(isLoadingSaved: false, savedJobs: jobs),
    );
  }

  /// Toggle save. Optimistic — the swipe action confirms instantly even if
  /// the network round-trip is in flight.
  Future<void> toggleSaveJob(String jobId) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    final isSaved = state.savedJobIds.contains(jobId);
    final next = Set<String>.from(state.savedJobIds);
    if (isSaved) {
      next.remove(jobId);
    } else {
      next.add(jobId);
    }
    state = state.copyWith(savedJobIds: next);
    final result = isSaved
        ? await _interactions.unsaveJob(userId, jobId)
        : await _interactions.saveJob(userId, jobId);
    result.fold((f) {
      // Roll back the optimistic mutation if the server rejects.
      final rollback = Set<String>.from(state.savedJobIds);
      if (isSaved) {
        rollback.add(jobId);
      } else {
        rollback.remove(jobId);
      }
      state = state.copyWith(savedJobIds: rollback, error: f.message);
    }, (_) {});
  }

  /// Hide a job from the active user's feed. Optimistically drops it from
  /// the in-memory paged list so the swipe feels instant.
  Future<void> hideJob(String jobId) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    final next = Set<String>.from(state.hiddenJobIds)..add(jobId);
    state = state.copyWith(hiddenJobIds: next);
    // Drop the row from the in-memory paged list so the user sees the
    // immediate effect — same pattern as the archive-conversation swipe.
    final paging = _pagingController;
    if (paging != null) {
      final current = paging.itemList ?? const <Job>[];
      paging.itemList = current.where((j) => j.id != jobId).toList();
    }
    final result = await _interactions.hideJob(userId, jobId);
    result.fold((f) => state = state.copyWith(error: f.message), (_) {});
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
    this.savedJobs = const [],
    this.savedJobIds = const {},
    this.hiddenJobIds = const {},
    this.filter,
    this.isLoading = false,
    this.isLoadingSaved = false,
    this.error,
  });

  final List<Job> jobs;
  final List<Job> savedJobs;
  final Set<String> savedJobIds;
  final Set<String> hiddenJobIds;
  final JobFilter? filter;
  final bool isLoading;
  final bool isLoadingSaved;
  final String? error;

  JobsState copyWith({
    List<Job>? jobs,
    List<Job>? savedJobs,
    Set<String>? savedJobIds,
    Set<String>? hiddenJobIds,
    JobFilter? filter,
    bool clearFilter = false,
    bool? isLoading,
    bool? isLoadingSaved,
    String? error,
  }) => JobsState(
    jobs: jobs ?? this.jobs,
    savedJobs: savedJobs ?? this.savedJobs,
    savedJobIds: savedJobIds ?? this.savedJobIds,
    hiddenJobIds: hiddenJobIds ?? this.hiddenJobIds,
    filter: clearFilter ? null : (filter ?? this.filter),
    isLoading: isLoading ?? this.isLoading,
    isLoadingSaved: isLoadingSaved ?? this.isLoadingSaved,
    error: error,
  );
}
