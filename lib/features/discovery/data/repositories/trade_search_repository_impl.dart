import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/trade_search_filter.dart';
import '../../domain/entities/trade_search_result.dart';
import '../../domain/repositories/trade_search_repository.dart';
import '../datasources/trade_search_remote_datasource.dart';

class TradeSearchRepositoryImpl implements TradeSearchRepository {
  const TradeSearchRepositoryImpl(this._datasource);
  final TradeSearchRemoteDataSource _datasource;

  @override
  Future<Either<Failure, List<TradeSearchResult>>> searchTrades({
    required TradeSearchFilter filter,
    int? limit,
    int? offset,
  }) async {
    try {
      return right(
        await _datasource.searchTrades(
          filter: filter,
          limit: limit,
          offset: offset,
        ),
      );
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }
}
