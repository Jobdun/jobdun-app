import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../data/datasources/verifications_remote_datasource.dart';
import '../../data/repositories/verifications_repository_impl.dart';
import '../../domain/entities/verification.dart';
import '../../domain/repositories/verifications_repository.dart';
import '../../domain/usecases/get_my_verifications.dart';
import '../../domain/usecases/invoke_verify_abn.dart';
import '../../domain/usecases/invoke_verify_licence.dart';

// ── Data layer providers (public for test overrides — CLAUDE.md) ──────────────
final verificationsDatasourceProvider = Provider<VerificationsRemoteDataSource>(
  (ref) => VerificationsRemoteDataSourceImpl(SupabaseConfig.client),
);

final verificationsRepositoryProvider = Provider<VerificationsRepository>(
  (ref) =>
      VerificationsRepositoryImpl(ref.read(verificationsDatasourceProvider)),
);

// ── Use cases ─────────────────────────────────────────────────────────────────
final getMyVerificationsUseCaseProvider = Provider(
  (ref) => GetMyVerifications(ref.read(verificationsRepositoryProvider)),
);

final invokeVerifyAbnUseCaseProvider = Provider(
  (ref) => InvokeVerifyAbn(ref.read(verificationsRepositoryProvider)),
);

final invokeVerifyLicenceUseCaseProvider = Provider(
  (ref) => InvokeVerifyLicence(ref.read(verificationsRepositoryProvider)),
);

// ── Per-user verifications (FutureProvider.family) ────────────────────────────
final verificationsForUserProvider =
    FutureProvider.family<List<Verification>, String>((ref, userId) async {
      final result = await ref
          .read(getMyVerificationsUseCaseProvider)
          .call(userId);
      return result.fold((f) => throw Exception(f.message), (rows) => rows);
    });

// Convenience: the current user's own verifications.
final myVerificationsProvider = Provider<AsyncValue<List<Verification>>>((ref) {
  final userId = ref.watch(currentUserIdSyncProvider);
  if (userId == null) return const AsyncData(<Verification>[]);
  return ref.watch(verificationsForUserProvider(userId));
});

// Derived: highest-level summary of a user's verification state, for UI.
enum VerificationSummary { none, partial, fullyVerified }

VerificationSummary summariseForTrade(List<Verification> rows) {
  final abnVerified = rows.any(
    (v) => v.kind == VerificationKind.abn && v.isVerified,
  );
  final licenceVerified = rows.any(
    (v) => v.kind == VerificationKind.licence && v.isVerified,
  );
  if (abnVerified && licenceVerified) return VerificationSummary.fullyVerified;
  if (abnVerified || licenceVerified) return VerificationSummary.partial;
  return VerificationSummary.none;
}

VerificationSummary summariseForBuilder(List<Verification> rows) {
  final abnVerified = rows.any(
    (v) => v.kind == VerificationKind.abn && v.isVerified,
  );
  return abnVerified
      ? VerificationSummary.fullyVerified
      : VerificationSummary.none;
}

// ── Per-session banner-dismissal flag ────────────────────────────────────────
// v2 spec: nudge banner reappears next session — Riverpod-only, no persistence.
class BannerDismissNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void dismiss() => state = true;
}

final verificationBannerDismissedProvider =
    NotifierProvider<BannerDismissNotifier, bool>(BannerDismissNotifier.new);

// ── Builder "include unverified workers" acknowledgement ─────────────────────
// Reads + writes `builder_unverified_acknowledgements`. Kept inside the
// providers/ layer so SupabaseConfig.client stays out of presentation/widgets/
// (Clean Architecture rule — see scripts/check-architecture.sh).
class BuilderAcknowledgementNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<bool> isAcknowledged() async {
    final userId = ref.read(currentUserIdSyncProvider);
    if (userId == null) return false;
    try {
      final row = await SupabaseConfig.client
          .from('builder_unverified_acknowledgements')
          .select('builder_id')
          .eq('builder_id', userId)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> markAcknowledged() async {
    final userId = ref.read(currentUserIdSyncProvider);
    if (userId == null) return;
    try {
      await SupabaseConfig.client
          .from('builder_unverified_acknowledgements')
          .insert({'builder_id': userId});
    } catch (_) {
      // PK conflict — already acknowledged. Treat as success.
    }
  }
}

final builderAcknowledgementProvider =
    NotifierProvider<BuilderAcknowledgementNotifier, void>(
      BuilderAcknowledgementNotifier.new,
    );
