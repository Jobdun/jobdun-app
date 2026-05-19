import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/legal_acceptance_repository.dart';
import '../../data/legal_document_repository.dart';
import '../../domain/legal_document.dart';

// ── Repositories ──────────────────────────────────────────────────────────────

final legalDocumentRepositoryProvider = Provider(
  (_) => LegalDocumentRepository(),
);

final legalAcceptanceRepositoryProvider = Provider(
  (_) => LegalAcceptanceRepository(Supabase.instance.client),
);

// ── Document loaders ──────────────────────────────────────────────────────────

final legalDocumentProvider =
    FutureProvider.family<LegalDocument, LegalDocumentType>((ref, type) async {
      final repo = ref.read(legalDocumentRepositoryProvider);
      final result = await repo.load(type);
      return result.fold((err) => throw Exception(err), (doc) => doc);
    });

// ── Version map from assets/legal/versions.json ───────────────────────────────

final legalVersionsProvider = FutureProvider<Map<String, String>>((ref) async {
  final repo = ref.read(legalDocumentRepositoryProvider);
  final result = await repo.versions();
  return result.fold((err) => throw Exception(err), (v) => v);
});

// ── Last accepted versions from Supabase ─────────────────────────────────────

final lastAcceptedVersionsProvider = FutureProvider<Map<String, String>>((
  ref,
) async {
  final repo = ref.read(legalAcceptanceRepositoryProvider);
  final result = await repo.lastAcceptedVersions();
  return result.fold((_) => {}, (v) => v);
});

// ── Re-acceptance check: returns doc types that need re-acceptance ────────────
// If currentVersion != lastAccepted, user must accept again.

final pendingReacceptanceProvider = FutureProvider<List<LegalDocumentType>>((
  ref,
) async {
  final current = await ref.watch(legalVersionsProvider.future);
  final accepted = await ref.watch(lastAcceptedVersionsProvider.future);

  final pending = <LegalDocumentType>[];
  for (final type in LegalDocumentType.values) {
    final cv = current[type.dbKey] ?? '1.0.0';
    final av = accepted[type.dbKey];
    if (av == null || av != cv) pending.add(type);
  }
  return pending;
});

// ── Acceptance action ─────────────────────────────────────────────────────────

final legalAcceptanceActionsProvider = Provider(
  (ref) => _LegalAcceptanceActions(ref),
);

class _LegalAcceptanceActions {
  const _LegalAcceptanceActions(this._ref);
  final Ref _ref;

  Future<void> recordBothDocuments() async {
    final versions = await _ref.read(legalVersionsProvider.future);
    final repo = _ref.read(legalAcceptanceRepositoryProvider);

    for (final type in LegalDocumentType.values) {
      final version = versions[type.dbKey] ?? '1.0.0';
      await repo.recordAcceptance(type: type, version: version);
    }
    // Invalidate so pendingReacceptanceProvider re-checks.
    _ref.invalidate(lastAcceptedVersionsProvider);
  }
}
