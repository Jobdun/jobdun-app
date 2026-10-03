import '../../domain/entities/job.dart';
import '../../domain/entities/job_filter.dart';

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
