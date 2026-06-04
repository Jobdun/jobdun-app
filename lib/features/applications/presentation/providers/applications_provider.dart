import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/account_scoped.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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

class ApplicationsController extends Notifier<ApplicationsState>
    with AccountScoped<ApplicationsState> {
  @override
  ApplicationsState build() {
    // Clear state on logout / account switch, then reload for the incoming
    // user. The initial load lives HERE — not in a page's `initState` +
    // `addPostFrameCallback` (forbidden by the Riverpod rules). The three
    // applications screens share this one controller, so loading once on first
    // read serves all of them.
    resetOnAccountChange((userId) {
      state = const ApplicationsState();
      if (userId != null) _autoLoad(userId);
    });
    final userId = readCurrentUserId(ref);
    if (userId != null) Future.microtask(() => _autoLoad(userId));
    return const ApplicationsState();
  }

  /// Role-appropriate load: builders get incoming applicants, tradies get
  /// their own applications. Used for the initial load and pull-to-refresh.
  void _autoLoad(String userId) {
    final isBuilder = ref.read(authControllerProvider).role == UserRole.builder;
    if (isBuilder) {
      loadIncomingApplications(userId);
    } else {
      loadMyApplications(userId);
    }
  }

  /// Flip the verified-only filter on the builder applicant list.
  /// The first-time consent dialog is owned by the page (caller must
  /// already have shown it before calling with false).
  void setVerifiedOnlyFilter(bool value) {
    state = state.copyWith(verifiedOnlyFilter: value);
  }

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

  // Trade: apply to a job. [builderId] is the JOB OWNER (recipient of the
  // application) — NOT the applicant. The repo sets trade_id from auth.uid().
  Future<bool> apply({
    required String jobId,
    required String builderId,
    String? coverNote,
    double? quoteAmount,
  }) async {
    final tradeId = readCurrentUserId(ref);
    if (tradeId == null) return false;
    final result = await ref
        .read(applyToJobUseCaseProvider)
        .call(
          jobId: jobId,
          builderId: builderId,
          coverNote: coverNote,
          quoteAmount: quoteAmount,
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
    this.verifiedOnlyFilter = true,
  });

  final List<JobApplication> myApplications; // trade view
  final List<JobApplication> incomingApplications; // builder view
  final bool isLoading;
  final String? error;

  // v2: builder-side filter — default ON. The applicant list shows only
  // tradies whose verification is currently active. Toggle exposes the
  // first-time consent dialog.
  final bool verifiedOnlyFilter;

  int get pendingIncomingCount => incomingApplications
      .where((a) => a.status == ApplicationStatus.pending)
      .length;

  /// v2 view used by the builder applicant list. Always returns rows in
  /// verified-first order; optionally hides unverified rows entirely.
  List<JobApplication> get filteredIncoming {
    final all = [...incomingApplications];
    all.sort((a, b) {
      final av = a.tradeIsVerified == true ? 0 : 1;
      final bv = b.tradeIsVerified == true ? 0 : 1;
      return av.compareTo(bv);
    });
    if (!verifiedOnlyFilter) return all;
    return all.where((a) => a.tradeIsVerified == true).toList();
  }

  ApplicationsState copyWith({
    List<JobApplication>? myApplications,
    List<JobApplication>? incomingApplications,
    bool? isLoading,
    String? error,
    bool? verifiedOnlyFilter,
  }) => ApplicationsState(
    myApplications: myApplications ?? this.myApplications,
    incomingApplications: incomingApplications ?? this.incomingApplications,
    isLoading: isLoading ?? this.isLoading,
    error: error,
    verifiedOnlyFilter: verifiedOnlyFilter ?? this.verifiedOnlyFilter,
  );
}
