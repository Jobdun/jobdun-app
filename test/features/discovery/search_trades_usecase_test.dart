import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_filter.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_result.dart';
import 'package:jobdun/features/discovery/domain/repositories/trade_search_repository.dart';
import 'package:jobdun/features/discovery/domain/usecases/search_trades.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';

class MockTradeSearchRepository extends Mock
    implements TradeSearchRepository {}

void main() {
  late SearchTrades useCase;
  late MockTradeSearchRepository repo;
  const filter = TradeSearchFilter(originLat: -33.8, originLng: 151.2);

  setUpAll(() => registerFallbackValue(const TradeSearchFilter()));
  setUp(() {
    repo = MockTradeSearchRepository();
    useCase = SearchTrades(repo);
  });

  const result = TradeSearchResult(
    trade: TradeProfile(id: 't1', fullName: 'Bob', primaryTrade: 'electrician'),
    distanceKm: 2.5,
  );

  test('forwards filter/limit/offset and returns results', () async {
    when(
      () => repo.searchTrades(filter: filter, limit: 20, offset: 0),
    ).thenAnswer((_) async => const Right([result]));

    final out = await useCase(filter: filter, limit: 20, offset: 0);

    expect(out.isRight(), isTrue);
    out.fold((_) => fail('expected results'), (l) => expect(l.length, 1));
    verify(
      () => repo.searchTrades(filter: filter, limit: 20, offset: 0),
    ).called(1);
  });

  test('propagates ServerFailure', () async {
    when(
      () => repo.searchTrades(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure('boom')));

    final out = await useCase(filter: filter);

    out.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected fail'),
    );
  });
}
