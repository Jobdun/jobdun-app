import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/trade_search_filter.dart';
import '../entities/trade_search_result.dart';
import '../repositories/trade_search_repository.dart';

class SearchTrades {
  const SearchTrades(this._repository);
  final TradeSearchRepository _repository;

  Future<Either<Failure, List<TradeSearchResult>>> call({
    required TradeSearchFilter filter,
    int? limit,
    int? offset,
  }) => _repository.searchTrades(filter: filter, limit: limit, offset: offset);
}
