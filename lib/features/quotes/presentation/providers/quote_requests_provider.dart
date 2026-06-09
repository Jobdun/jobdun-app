import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../data/datasources/quote_request_remote_datasource.dart';
import '../../data/repositories/quote_request_repository_impl.dart';
import '../../domain/entities/quote_request.dart';
import '../../domain/repositories/quote_request_repository.dart';
import '../../domain/usecases/create_quote_request.dart';
import '../../domain/usecases/decline_quote_request.dart';
import '../../domain/usecases/get_quote_request_for_job_trade.dart';
import '../../domain/usecases/get_received_quote_requests.dart';
import '../../domain/usecases/respond_to_quote_request.dart';

// ── Data layer (public so tests can override) ─────────────────────────────────
final quoteRequestDatasourceProvider = Provider<QuoteRequestRemoteDataSource>(
  (ref) => QuoteRequestRemoteDataSourceImpl(SupabaseConfig.client),
);

final quoteRequestRepositoryProvider = Provider<QuoteRequestRepository>(
  (ref) => QuoteRequestRepositoryImpl(ref.read(quoteRequestDatasourceProvider)),
);

// ── Use cases ─────────────────────────────────────────────────────────────────
final createQuoteRequestUseCaseProvider = Provider(
  (ref) => CreateQuoteRequest(ref.read(quoteRequestRepositoryProvider)),
);
final getReceivedQuoteRequestsUseCaseProvider = Provider(
  (ref) => GetReceivedQuoteRequests(ref.read(quoteRequestRepositoryProvider)),
);
final getQuoteRequestForJobTradeUseCaseProvider = Provider(
  (ref) => GetQuoteRequestForJobTrade(ref.read(quoteRequestRepositoryProvider)),
);
final respondToQuoteRequestUseCaseProvider = Provider(
  (ref) => RespondToQuoteRequest(ref.read(quoteRequestRepositoryProvider)),
);
final declineQuoteRequestUseCaseProvider = Provider(
  (ref) => DeclineQuoteRequest(ref.read(quoteRequestRepositoryProvider)),
);

// ── Reads ─────────────────────────────────────────────────────────────────────
/// Trade inbox — quote requests addressed to the signed-in trade.
final receivedQuoteRequestsProvider =
    FutureProvider.autoDispose<List<QuoteRequest>>((ref) async {
      final tradeId = readCurrentUserId(ref);
      if (tradeId == null) return const [];
      final result = await ref
          .read(getReceivedQuoteRequestsUseCaseProvider)
          .call(tradeId);
      return result.fold((f) => throw Exception(f.message), (list) => list);
    });

/// Builder view — the request (if any) the builder has sent a trade for a job.
/// Drives the "Request a quote" affordance on the applicant screen.
final quoteRequestForProvider = FutureProvider.autoDispose
    .family<QuoteRequest?, ({String jobId, String tradeId})>((ref, key) async {
      final result = await ref
          .read(getQuoteRequestForJobTradeUseCaseProvider)
          .call(key.jobId, key.tradeId);
      return result.fold((f) => throw Exception(f.message), (q) => q);
    });

// ── Actions ───────────────────────────────────────────────────────────────────
/// Imperative create/respond/decline; each invalidates the relevant read so the
/// inbox or builder affordance refreshes. Thin seam (mirrors `AdminModeration`).
final quoteRequestActionsProvider = Provider(QuoteRequestActions.new);

class QuoteRequestActions {
  QuoteRequestActions(this._ref);
  final Ref _ref;

  Future<bool> create({
    required String jobId,
    required String tradeId,
    String? requestNote,
  }) async {
    final builderId = readCurrentUserId(_ref);
    if (builderId == null) return false;
    final result = await _ref
        .read(createQuoteRequestUseCaseProvider)
        .call(
          jobId: jobId,
          builderId: builderId,
          tradeId: tradeId,
          requestNote: requestNote,
        );
    if (result.isRight()) {
      _ref.invalidate(
        quoteRequestForProvider((jobId: jobId, tradeId: tradeId)),
      );
    }
    return result.isRight();
  }

  Future<bool> respond({
    required String requestId,
    required double quoteAmount,
    String? responseNote,
  }) async {
    final result = await _ref
        .read(respondToQuoteRequestUseCaseProvider)
        .call(
          requestId: requestId,
          quoteAmount: quoteAmount,
          responseNote: responseNote,
        );
    if (result.isRight()) _ref.invalidate(receivedQuoteRequestsProvider);
    return result.isRight();
  }

  Future<bool> decline(String requestId) async {
    final result = await _ref
        .read(declineQuoteRequestUseCaseProvider)
        .call(requestId);
    if (result.isRight()) _ref.invalidate(receivedQuoteRequestsProvider);
    return result.isRight();
  }
}
