import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../entities/trade_search_filter.dart';
import '../entities/trade_search_result.dart';

abstract interface class TradeSearchRepository {
  /// Geo + rating + availability search. When [limit] is null all matching
  /// rows are returned (one-shot, e.g. home mini-list); when set, returns the
  /// slice `[offset, offset + limit)`.
  Future<Either<Failure, List<TradeSearchResult>>> searchTrades({
    required TradeSearchFilter filter,
    int? limit,
    int? offset,
  });
}
