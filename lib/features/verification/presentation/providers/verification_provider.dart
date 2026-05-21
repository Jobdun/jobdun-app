import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../data/datasources/verification_remote_datasource.dart';
import '../../data/repositories/verification_repository_impl.dart';
import '../../domain/entities/verification_document.dart';
import '../../domain/repositories/verification_repository.dart';
import '../../domain/usecases/delete_document.dart';
import '../../domain/usecases/get_my_documents.dart';
import '../../domain/usecases/upload_document.dart';

// ── Data layer providers (public so tests can override) ───────────────────────
final verificationDatasourceProvider = Provider<VerificationRemoteDataSource>(
  (ref) => VerificationRemoteDataSourceImpl(SupabaseConfig.client),
);

final verificationRepositoryProvider = Provider<VerificationRepository>(
  (ref) => VerificationRepositoryImpl(ref.read(verificationDatasourceProvider)),
);

// ── Use cases ─────────────────────────────────────────────────────────────────
final getMyDocumentsUseCaseProvider = Provider(
  (ref) => GetMyDocuments(ref.read(verificationRepositoryProvider)),
);

final uploadDocumentUseCaseProvider = Provider(
  (ref) => UploadDocument(ref.read(verificationRepositoryProvider)),
);

final deleteDocumentUseCaseProvider = Provider(
  (ref) => DeleteDocument(ref.read(verificationRepositoryProvider)),
);

// ── Controller ────────────────────────────────────────────────────────────────
final verificationControllerProvider =
    NotifierProvider<VerificationController, VerificationState>(
      VerificationController.new,
    );

class VerificationController extends Notifier<VerificationState> {
  late VerificationRepository _repo;
  StreamSubscription<List<VerificationDocument>>? _sub;

  @override
  VerificationState build() {
    _repo = ref.read(verificationRepositoryProvider);
    ref.onDispose(() => _sub?.cancel());
    Future.microtask(_loadAndWatch);
    return const VerificationState();
  }

  Future<void> _loadAndWatch() async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return;
    await load();
    _sub?.cancel();
    _sub = _repo
        .watchMyDocuments(userId)
        .listen(
          (docs) => state = state.copyWith(documents: docs),
          onError: (Object e) => state = state.copyWith(error: e.toString()),
        );
  }

  Future<void> load() async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return;
    state = state.copyWith(isLoading: true, error: null);
    final result = await ref.read(getMyDocumentsUseCaseProvider).call(userId);
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (docs) => state = state.copyWith(isLoading: false, documents: docs),
    );
  }

  Future<bool> upload({
    required DocType docType,
    required File file,
    String? state,
    String? issuer,
    String? documentNumber,
    DateTime? issuedDate,
    DateTime? expiryDate,
  }) async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return false;
    this.state = this.state.copyWith(isUploading: true, error: null);
    final result = await ref
        .read(uploadDocumentUseCaseProvider)
        .call(
          tradeId: userId,
          docType: docType,
          file: file,
          state: state,
          issuer: issuer,
          documentNumber: documentNumber,
          issuedDate: issuedDate,
          expiryDate: expiryDate,
        );
    return result.fold(
      (f) {
        this.state = this.state.copyWith(isUploading: false, error: f.message);
        return false;
      },
      (_) {
        this.state = this.state.copyWith(isUploading: false);
        return true;
      },
    );
  }

  Future<bool> delete(String documentId) async {
    final result = await ref
        .read(deleteDocumentUseCaseProvider)
        .call(documentId);
    return result.fold((f) {
      state = state.copyWith(error: f.message);
      return false;
    }, (_) => true);
  }
}

class VerificationState {
  const VerificationState({
    this.documents = const [],
    this.isLoading = false,
    this.isUploading = false,
    this.error,
  });

  final List<VerificationDocument> documents;
  final bool isLoading;
  final bool isUploading;
  final String? error;

  VerificationState copyWith({
    List<VerificationDocument>? documents,
    bool? isLoading,
    bool? isUploading,
    String? error,
  }) => VerificationState(
    documents: documents ?? this.documents,
    isLoading: isLoading ?? this.isLoading,
    isUploading: isUploading ?? this.isUploading,
    error: error,
  );
}
