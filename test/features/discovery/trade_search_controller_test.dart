import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_filter.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_result.dart';
import 'package:jobdun/features/discovery/domain/repositories/trade_search_repository.dart';
import 'package:jobdun/features/discovery/presentation/providers/discovery_provider.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';

class MockRepo extends Mock implements TradeSearchRepository {}

TradeSearchResult _hit(String id, double d) => TradeSearchResult(
  trade: TradeProfile(id: id, fullName: 'T$id', primaryTrade: 'electrician'),
  distanceKm: d,
);

void main() {
  late MockRepo repo;
  setUpAll(() => registerFallbackValue(const TradeSearchFilter()));
  setUp(() => repo = MockRepo());

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        tradeSearchRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWith((ref) => Stream.value('builder-1')),
        currentUserIdSyncProvider.overrideWithValue('builder-1'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('loadFeed populates results from the repo', () async {
    when(
      () => repo.searchTrades(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => Right([_hit('a', 1), _hit('b', 2)]));

    final c = makeContainer();
    await c.read(tradeSearchControllerProvider.notifier).loadFeed();

    expect(c.read(tradeSearchControllerProvider).results.length, 2);
  });

  test('updateFilter stores the new filter and reloads', () async {
    when(
      () => repo.searchTrades(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => const Right([]));

    final c = makeContainer();
    await c
        .read(tradeSearchControllerProvider.notifier)
        .updateFilter(
          const TradeSearchFilter(radiusKm: 10, availableOnly: true),
        );

    final s = c.read(tradeSearchControllerProvider);
    expect(s.filter.radiusKm, 10);
    expect(s.filter.availableOnly, isTrue);
  });

  test('error from repo lands on state.error', () async {
    when(
      () => repo.searchTrades(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('boom')));

    final c = makeContainer();
    await c.read(tradeSearchControllerProvider.notifier).loadFeed();

    expect(c.read(tradeSearchControllerProvider).error, isNotNull);
  });
}
