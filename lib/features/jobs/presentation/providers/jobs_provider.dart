import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/job.dart';
import '../../domain/entities/job_filter.dart';

final jobsControllerProvider =
    NotifierProvider<JobsController, JobsState>(JobsController.new);

class JobsController extends Notifier<JobsState> {
  @override
  JobsState build() => const JobsState();
}

class JobsState {
  const JobsState({
    this.jobs = const [],
    this.filter,
    this.selectedJob,
    this.isLoading = false,
    this.error,
  });

  final List<Job> jobs;
  final JobFilter? filter;
  final Job? selectedJob;
  final bool isLoading;
  final String? error;

  JobsState copyWith({
    List<Job>? jobs,
    JobFilter? filter,
    Job? selectedJob,
    bool? isLoading,
    String? error,
  }) =>
      JobsState(
        jobs: jobs ?? this.jobs,
        filter: filter ?? this.filter,
        selectedJob: selectedJob ?? this.selectedJob,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}
