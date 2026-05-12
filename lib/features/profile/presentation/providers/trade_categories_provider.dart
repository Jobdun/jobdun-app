import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../data/models/trade_category_model.dart';

// Fetched once per session and cached. Sorted by (group, sort_order) so the
// picker can split into groups without re-sorting client-side.
final tradeCategoriesProvider = FutureProvider<List<TradeCategory>>((
  ref,
) async {
  if (!SupabaseConfig.isInitialized) return const [];

  final rows = await SupabaseConfig.client
      .from('trade_categories')
      .select()
      .order('category', ascending: true)
      .order('sort_order', ascending: true);

  return (rows as List<dynamic>)
      .map((row) => TradeCategory.fromJson(row as Map<String, dynamic>))
      .toList(growable: false);
});
