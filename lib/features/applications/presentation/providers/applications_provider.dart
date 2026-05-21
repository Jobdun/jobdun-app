import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../data/datasources/application_remote_datasource.dart';
import '../../data/repositories/application_repository_impl.dart';
import '../../domain/entities/job_application.dart';
import '../../domain/repositories/application_repository.dart';
import '../../domain/usecases/apply_to_job.dart';
import '../../domain/usecases/get_job_applications.dart';
import '../../domain/usecases/get_my_applications.dart';
import '../../domain/usecases/update_application_status.dart';
import '../../domain/usecases/withdraw_application.dart';

// ── Data layer providers (public so tests can override) ───────────────────────
final applicationDatasourceProvider = Provider<ApplicationRemoteDataSource>(
  (ref) => ApplicationRemoteDataSourceImpl(SupabaseConfig.client),
);

final applicationRepositoryProvider = Provider<ApplicationRepository>(
  (ref) => ApplicationRepositoryImpl(
    ref.read(applicationDatasourceProvider),
    SupabaseConfig.client,
  ),
);

// ── Use cases ─────────────────────────────────────────────────────────────────
final applyToJobUseCaseProvider = Provider(
  (ref) => ApplyToJob(ref.read(applicationRepositoryProvider)),
);

final getMyApplicationsUseCaseProvider = Provider(
  (ref) => GetMyApplications(ref.read(applicationRepositoryProvider)),
);

final getApplicationsForMyJobsUseCaseProvider = Provider(
  (ref) => GetApplicationsForMyJobs(ref.read(applicationRepositoryProvider)),
);

final updateApplicationStatusUseCaseProvider = Provider(
  (ref) => UpdateApplicationStatus(ref.read(applicationRepositoryProvider)),
);

final withdrawApplicationUseCaseProvider = Provider(
  (ref) => WithdrawApplication(ref.read(applicationRepositoryProvider)),
);

// ── Controller ────────────────────────────────────────────────────────────────
final applicationsControllerProvider =
    NotifierProvider<ApplicationsController, ApplicationsState>(
      ApplicationsController.new,
    );

class ApplicationsController extends Notifier<ApplicationsState> {
  @override
  ApplicationsState build() => const ApplicationsState();

  // Trade: load their own applications
  Future<void> loadMyApplications(String tradeId) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await ref
        .read(getMyApplicationsUseCaseProvider)
        .call(tradeId);
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (apps) => state = state.copyWith(isLoading: false, myApplications: apps),
    );
  }

  // Builder: load applications to their posted jobs
  Future<void> loadIncomingApplications(String builderId) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await ref
        .read(getApplicationsForMyJobsUseCaseProvider)
        .call(builderId);
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
    final result = await ref
        .read(updateApplicationStatusUseCaseProvider)
        .call(applicationId, status);
    result.fold((f) => state = state.copyWith(error: f.message), (_) {
      final builderId = readCurrentUserId(ref);
      if (builderId != null) {
        unawaited(loadIncomingApplications(builderId));
      }
    });
  }

  // Trade: withdraw their application
  Future<void> withdraw(String applicationId) async {
    final result = await ref
        .read(withdrawApplicationUseCaseProvider)
        .call(applicationId);
    result.fold((f) => state = state.copyWith(error: f.message), (_) {
      final tradeId = readCurrentUserId(ref);
      if (tradeId != null) unawaited(loadMyApplications(tradeId));
    });
  }

  // Trade: apply to a job
  Future<bool> apply({
    required String jobId,
    String? coverNote,
    double? proposedRate,
    String? proposedRateType,
  }) async {
    final tradeId = readCurrentUserId(ref);
    if (tradeId == null) return false;
    final result = await ref
        .read(applyToJobUseCaseProvider)
        .call(
          jobId: jobId,
          builderId: tradeId,
          coverNote: coverNote,
          proposedRate: proposedRate,
          proposedRateType: proposedRateType,
        );
    return result.fold(
      (f) {
        state = state.copyWith(error: f.message);
        return false;
      },
      (_) {
        unawaited(loadMyApplications(tradeId));
        return true;
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

  final List<JobApplication> myApplications; // trade view
  final List<JobApplication> incomingApplications; // builder view
  final bool isLoading;
  final String? error;

  int get pendingIncomingCount => incomingApplications
      .where((a) => a.status == ApplicationStatus.pending)
      .length;

  ApplicationsState copyWith({
    List<JobApplication>? myApplications,
    List<JobApplication>? incomingApplications,
    bool? isLoading,
    String? error,
  }) => ApplicationsState(
    myApplications: myApplications ?? this.myApplications,
    incomingApplications: incomingApplications ?? this.incomingApplications,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}
