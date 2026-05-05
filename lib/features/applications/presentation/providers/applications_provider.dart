import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/job_application.dart';

final applicationsControllerProvider =
    NotifierProvider<ApplicationsController, ApplicationsState>(
  ApplicationsController.new,
);

class ApplicationsController extends Notifier<ApplicationsState> {
  @override
  ApplicationsState build() => const ApplicationsState();
}

class ApplicationsState {
  const ApplicationsState({
    this.applications = const [],
    this.isLoading = false,
    this.error,
  });

  final List<JobApplication> applications;
  final bool isLoading;
  final String? error;

  ApplicationsState copyWith({
    List<JobApplication>? applications,
    bool? isLoading,
    String? error,
  }) =>
      ApplicationsState(
        applications: applications ?? this.applications,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}
