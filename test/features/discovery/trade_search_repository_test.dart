import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/core/errors/exceptions.dart';
import 'package:jobdun/core/errors/failures.dart';
import 'package:jobdun/features/discovery/data/datasources/trade_search_remote_datasource.dart';
import 'package:jobdun/features/discovery/data/repositories/trade_search_repository_impl.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_filter.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_result.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';

class MockDs extends Mock implements TradeSearchRemoteDataSource {}

void main() {
  late TradeSearchRepositoryImpl repo;
  late MockDs ds;
  const filter = TradeSearchFilter(originLat: -33.8, originLng: 151.2);
  const hit = TradeSearchResult(
    trade: TradeProfile(id: 't1', fullName: 'Bob', primaryTrade: 'electrician'),
    distanceKm: 2.5,
  );

  setUpAll(() => registerFallbackValue(const TradeSearchFilter()));
  setUp(() {
    ds = MockDs();
    repo = TradeSearchRepositoryImpl(ds);
  });

  test('returns Right(results) on success', () async {
    when(
      () => ds.searchTrades(filter: filter, limit: 20, offset: 0),
    ).thenAnswer((_) async => const [hit]);

    final out = await repo.searchTrades(filter: filter, limit: 20, offset: 0);

    out.fold((_) => fail('expected results'), (l) => expect(l.single, hit));
  });

  test('maps ServerException to Left(ServerFailure)', () async {
    when(
      () => ds.searchTrades(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenThrow(const ServerException('rpc failed'));

    final out = await repo.searchTrades(filter: filter);

    out.fold(
      (f) => expect(f, isA<ServerFailure>()),
      (_) => fail('expected fail'),
    );
  });
}
