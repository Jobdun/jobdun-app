import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../data/models/site_ticket_model.dart';
import '../../domain/entities/site_ticket.dart';

/// Reference data — `public.site_tickets`. Fetched once per session and cached
/// by Riverpod. Public (no leading underscore) so widget tests can override it
/// through `ProviderScope(overrides: [...])`.
///
/// Reads Supabase directly, exactly as `tradeCategoriesProvider` does. That is
/// allowed here: `check-architecture.sh` exempts `presentation/providers/` from
/// the Supabase-isolation rule, and read-only reference data has no repository
/// to route through.
final siteTicketsProvider = FutureProvider<List<SiteTicket>>((ref) async {
  if (!SupabaseConfig.isInitialized) return const [];

  final rows = await SupabaseConfig.client
      .from('site_tickets')
      .select()
      .order('category', ascending: true)
      .order('sort_order', ascending: true);

  return (rows as List<dynamic>)
      .map((row) => SiteTicketModel.fromJson(row as Map<String, dynamic>))
      .toList(growable: false);
});

/// Groups tickets for the sheet's section headers.
///
/// Category order is the enum declaration order (induction → safety → licence
/// → transport), which runs from "every site asks for this" down to "nice to
/// have"; within a category the rows keep their `sort_order`. Empty categories
/// are dropped so the sheet never renders a header with nothing under it.
Map<SiteTicketCategory, List<SiteTicket>> groupTicketsByCategory(
  List<SiteTicket> tickets,
) {
  final out = <SiteTicketCategory, List<SiteTicket>>{};
  for (final category in SiteTicketCategory.values) {
    final rows = tickets.where((t) => t.category == category).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (rows.isNotEmpty) out[category] = rows;
  }
  return out;
}
