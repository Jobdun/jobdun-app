import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../data/datasources/application_remote_datasource.dart';
import '../../data/repositories/application_repository_impl.dart';
import '../../domain/entities/job_application.dart';
import '../../domain/repositories/application_repository.dart';

final _appDatasourceProvider = Provider<ApplicationRemoteDataSource>(
  (ref) => ApplicationRemoteDataSourceImpl(SupabaseConfig.client),
);

final _appRepositoryProvider = Provider<ApplicationRepository>(
  (ref) => ApplicationRepositoryImpl(
    ref.read(_appDatasourceProvider),
    SupabaseConfig.client,
  ),
);

final applicationsControllerProvider =
    NotifierProvider<ApplicationsController, ApplicationsState>(
  ApplicationsController.new,
);

class ApplicationsController extends Notifier<ApplicationsState> {
  late ApplicationRepository _repo;

  @override
  ApplicationsState build() {
    _repo = ref.read(_appRepositoryProvider);
    return const ApplicationsState();
  }

  // Trade: load their own applications
  Future<void> loadMyApplications(String tradeId) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repo.getMyApplications(tradeId);
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (apps) => state = state.copyWith(isLoading: false, myApplications: apps),
    );
  }

  // Builder: load applications to their posted jobs
  Future<void> loadIncomingApplications(String builderId) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repo.getApplicationsForMyJobs(builderId);
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (apps) =>
          state = state.copyWith(isLoading: false, incomingApplications: apps),
    );
  }

  // Builder: shortlist, hire, or reject an applicant
  Future<void> updateStatus(
    String applicationId,
    ApplicationStatus status,
  ) async {
    final result = await _repo.updateStatus(applicationId, status);
    result.fold(
      (f) => state = state.copyWith(error: f.message),
      (_) {
        final builderId = SupabaseConfig.client.auth.currentUser?.id;
        if (builderId != null) {
          unawaited(loadIncomingApplications(builderId));
        }
      },
    );
  }

  // Trade: withdraw their application
  Future<void> withdraw(String applicationId) async {
    final result = await _repo.withdraw(applicationId);
    result.fold(
      (f) => state = state.copyWith(error: f.message),
      (_) {
        final tradeId = SupabaseConfig.client.auth.currentUser?.id;
        if (tradeId != null) unawaited(loadMyApplications(tradeId));
      },
    );
  }
}

class ApplicationsState {
  const ApplicationsState({
    this.myApplications = const [],
    this.incomingApplications = const [],
    this.isLoading = false,
    this.error,
  });

  final List<JobApplication> myApplications;      // trade view
  final List<JobApplication> incomingApplications; // builder view
  final bool isLoading;
  final String? error;

  int get pendingIncomingCount =>
      incomingApplications.where((a) => a.status == ApplicationStatus.pending).length;

  ApplicationsState copyWith({
    List<JobApplication>? myApplications,
    List<JobApplication>? incomingApplications,
    bool? isLoading,
    String? error,
  }) =>
      ApplicationsState(
        myApplications: myApplications ?? this.myApplications,
        incomingApplications: incomingApplications ?? this.incomingApplications,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}
