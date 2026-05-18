import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class JobsController extends Notifier<JobsState> {
  late JobRepository _repo;
  StreamSubscription<List<Job>>? _builderJobsSub;

  @override
  JobsState build() {
    _repo = ref.read(_jobRepositoryProvider);
    ref.onDispose(() => _builderJobsSub?.cancel());
    return const JobsState();
  }

  Future<void> loadFeed() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repo.getJobs(filter: state.filter);
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

  /// Find Jobs (T3) paged fetch. Independent of [loadFeed] — does NOT mutate
  /// the shared home-feed [state]; the PagingController owns the page list.
  /// Throws on failure so the PagingController can surface the error.
  Future<List<Job>> fetchPage({
    required int page,
    required JobFilter filter,
  }) async {
    final result = await _repo.getJobs(filter: filter.copyWith(page: page));
    return result.fold((f) => throw Exception(f.message), (jobs) => jobs);
  }

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
