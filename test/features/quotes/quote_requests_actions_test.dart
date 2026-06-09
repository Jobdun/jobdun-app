import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/quotes/domain/entities/quote_request.dart';
import 'package:jobdun/features/quotes/domain/repositories/quote_request_repository.dart';
import 'package:jobdun/features/quotes/presentation/providers/quote_requests_provider.dart';

class _FakeRepo implements QuoteRequestRepository {
  String? createdJob, createdBuilder, createdTrade;
  String? respondedId;
  double? respondedAmount;
  String? declinedId;

  @override
  Future<Either<Failure, QuoteRequest>> create({
    required String jobId,
    required String builderId,
    required String tradeId,
    String? requestNote,
  }) async {
    createdJob = jobId;
    createdBuilder = builderId;
    createdTrade = tradeId;
    return Right(
      QuoteRequest(
        id: 'q1',
        jobId: jobId,
        builderId: builderId,
        tradeId: tradeId,
        status: QuoteRequestStatus.requested,
        createdAt: DateTime(2026),
      ),
    );
  }

  @override
  Future<Either<Failure, void>> respond({
    required String requestId,
    required double quoteAmount,
    String? responseNote,
  }) async {
    respondedId = requestId;
    respondedAmount = quoteAmount;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> decline(String requestId) async {
    declinedId = requestId;
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<QuoteRequest>>> getReceived(
    String tradeId,
  ) async => const Right([]);

  @override
  Future<Either<Failure, QuoteRequest?>> getForJobTrade(
    String jobId,
    String tradeId,
  ) async => const Right(null);
}

ProviderContainer _container(_FakeRepo repo, {String? uid = 'b1'}) =>
    ProviderContainer(
      overrides: [
        quoteRequestRepositoryProvider.overrideWithValue(repo),
        currentUserIdSyncProvider.overrideWithValue(uid),
      ],
    );

void main() {
  test('create stamps builderId from the signed-in user + forwards', () async {
    final repo = _FakeRepo();
    final c = _container(repo);
    addTearDown(c.dispose);

    final ok = await c
        .read(quoteRequestActionsProvider)
        .create(jobId: 'j1', tradeId: 't1');

    expect(ok, isTrue);
    expect(repo.createdBuilder, 'b1');
    expect(repo.createdJob, 'j1');
    expect(repo.createdTrade, 't1');
  });

  test('create returns false (and no call) when signed out', () async {
    final repo = _FakeRepo();
    final c = _container(repo, uid: null);
    addTearDown(c.dispose);

    final ok = await c
        .read(quoteRequestActionsProvider)
        .create(jobId: 'j1', tradeId: 't1');

    expect(ok, isFalse);
    expect(repo.createdJob, isNull);
  });

  test('respond forwards the request id + amount', () async {
    final repo = _FakeRepo();
    final c = _container(repo);
    addTearDown(c.dispose);

    final ok = await c
        .read(quoteRequestActionsProvider)
        .respond(requestId: 'q1', quoteAmount: 999);

    expect(ok, isTrue);
    expect(repo.respondedId, 'q1');
    expect(repo.respondedAmount, 999);
  });

  test('decline forwards the request id', () async {
    final repo = _FakeRepo();
    final c = _container(repo);
    addTearDown(c.dispose);

    final ok = await c.read(quoteRequestActionsProvider).decline('q1');

    expect(ok, isTrue);
    expect(repo.declinedId, 'q1');
  });
}
