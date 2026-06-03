import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../profile/data/models/trade_profile_model.dart';
import '../../domain/entities/trade_search_filter.dart';
import '../../domain/entities/trade_search_result.dart';

abstract interface class TradeSearchRemoteDataSource {
  Future<List<TradeSearchResult>> searchTrades({
    required TradeSearchFilter filter,
    int? limit,
    int? offset,
  });
}

class TradeSearchRemoteDataSourceImpl implements TradeSearchRemoteDataSource {
  const TradeSearchRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<List<TradeSearchResult>> searchTrades({
    required TradeSearchFilter filter,
    int? limit,
    int? offset,
  }) async {
    try {
      final q = filter.query?.trim();
      final data =
          await _client.rpc(
                'search_trades',
                params: {
                  'p_lat': filter.originLat,
                  'p_lng': filter.originLng,
                  'p_radius_km': filter.radiusKm,
                  'p_min_rating': filter.minRating,
                  'p_available_only': filter.availableOnly,
                  'p_query': (q == null || q.isEmpty) ? null : q,
                  'p_limit': limit ?? 1000,
                  'p_offset': offset ?? 0,
                },
              )
              as List<dynamic>;

      return data.map((e) {
        final row = e as Map<String, dynamic>;
        return TradeSearchResult(
          trade: TradeProfileModel.fromJson(row),
          distanceKm: (row['distance_km'] as num).toDouble(),
        );
      }).toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
