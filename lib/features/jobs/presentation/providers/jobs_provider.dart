import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../data/datasources/job_interactions_datasource.dart';
import '../../data/datasources/job_remote_datasource.dart';
import '../../data/repositories/job_interactions_repository_impl.dart';
import '../../data/repositories/job_repository_impl.dart';
import '../../domain/entities/job.dart';
import '../../domain/entities/job_filter.dart';
import '../../domain/repositories/job_interactions_repository.dart';
import '../../domain/repositories/job_repository.dart';
import '../../domain/usecases/create_job.dart';
import '../../domain/usecases/delete_job.dart';
import '../../domain/usecases/get_job_by_id.dart';
import '../../domain/usecases/get_jobs.dart';
import '../../domain/usecases/update_job.dart';

// ── Data layer providers (public so tests can override) ───────────────────────
final jobDatasourceProvider = Provider<JobRemoteDataSource>(
  (ref) => JobRemoteDataSourceImpl(SupabaseConfig.client),
);

final jobRepositoryProvider = Provider<JobRepository>(
  (ref) => JobRepositoryImpl(ref.read(jobDatasourceProvider)),
);

final jobInteractionsDatasourceProvider = Provider<JobInteractionsDataSource>(
  (ref) => JobInteractionsDataSourceImpl(SupabaseConfig.client),
);

final jobInteractionsRepositoryProvider = Provider<JobInteractionsRepository>(
  (ref) => JobInteractionsRepositoryImpl(
    ref.read(jobInteractionsDatasourceProvider),
  ),
);

// ── Use cases ─────────────────────────────────────────────────────────────────
// No use case exists for job-interactions (save/hide) — those go through the
// repo directly until a use case is added. See CLAUDE.md → Engineering Standards.
final getJobsUseCaseProvider = Provider(
  (ref) => GetJobs(ref.read(jobRepositoryProvider)),
);

final getJobByIdUseCaseProvider = Provider(
  (ref) => GetJobById(ref.read(jobRepositoryProvider)),
);

final createJobUseCaseProvider = Provider(
  (ref) => CreateJob(ref.read(jobRepositoryProvider)),
);

final updateJobUseCaseProvider = Provider(
  (ref) => UpdateJob(ref.read(jobRepositoryProvider)),
);

final deleteJobUseCaseProvider = Provider(
  (ref) => DeleteJob(ref.read(jobRepositoryProvider)),
);

// ── Controller ────────────────────────────────────────────────────────────────
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
class JobsController extends Notifier<JobsState> {
  late JobRepository _repo;
  late JobInteractionsRepository _interactions;
  StreamSubscription<List<Job>>? _builderJobsSub;
  PagingController<int, Job>? _pagingController;

  static const _pageSize = 20;

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
    _repo = ref.read(jobRepositoryProvider);
    _interactions = ref.read(jobInteractionsRepositoryProvider);
    ref.onDispose(() {
      _builderJobsSub?.cancel();
      _pagingController?.dispose();
    });
    return const JobsState();
  }

  Future<void> loadInteractionIds() async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return;
    final savedResult = await _interactions.getSavedJobIds(userId);
    final hiddenResult = await _interactions.getHiddenJobIds(userId);
    state = state.copyWith(
      savedJobIds: savedResult.fold((_) => const <String>{}, (ids) => ids),
      hiddenJobIds: hiddenResult.fold((_) => const <String>{}, (ids) => ids),
    );
  }

  Future<void> _fetchPage(int pageKey) async {
    final result = await ref
        .read(getJobsUseCaseProvider)
        .call(
          filter: state.filter,
          limit: _pageSize,
          offset: pageKey * _pageSize,
        );
    result.fold((f) => _pagingController?.error = f.message, (jobs) {
      final visible = state.hiddenJobIds.isEmpty
          ? jobs
          : jobs.where((j) => !state.hiddenJobIds.contains(j.id)).toList();

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

  Future<void> loadFeed() async {
    final paging = _pagingController;
    if (paging != null) {
      paging.refresh();
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    final result = await ref
        .read(getJobsUseCaseProvider)
        .call(filter: state.filter, limit: _pageSize);
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

  Future<void> loadSavedJobs() async {
    final userId = readCurrentUserId(ref);
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
    final userId = readCurrentUserId(ref);
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
    final userId = readCurrentUserId(ref);
    if (userId == null) return;
    final next = Set<String>.from(state.hiddenJobIds)..add(jobId);
    state = state.copyWith(hiddenJobIds: next);
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
