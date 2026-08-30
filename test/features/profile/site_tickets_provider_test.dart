import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/domain/entities/site_ticket.dart';
import 'package:jobdun/features/profile/presentation/providers/site_tickets_provider.dart';

const _whiteCard = SiteTicket(
  slug: 'white_card',
  shortName: 'White Card',
  displayName: 'White Card (Construction Induction, CPCCWHS1001)',
  category: SiteTicketCategory.induction,
  sortOrder: 10,
  docType: 'white_card',
);

void main() {
  test('returns an empty list when Supabase is not initialised', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(siteTicketsProvider.future), isEmpty);
  });

  test('is overridable so widget tests can inject fixtures', () async {
    final container = ProviderContainer(
      overrides: [
        siteTicketsProvider.overrideWith((ref) async => const [_whiteCard]),
      ],
    );
    addTearDown(container.dispose);
    final tickets = await container.read(siteTicketsProvider.future);
    expect(tickets.single.slug, 'white_card');
    expect(tickets.single.isVerifiable, isTrue);
  });

  group('groupTicketsByCategory', () {
    test('orders categories by declaration, rows by sort_order', () {
      const rows = [
        SiteTicket(
          slug: 'dogging',
          shortName: 'Dogging',
          displayName: 'Dogging Licence (DG)',
          category: SiteTicketCategory.licence,
          sortOrder: 30,
        ),
        _whiteCard,
        SiteTicket(
          slug: 'ewp_yellow_card',
          shortName: 'EWP Yellow Card',
          displayName: 'EWP Yellow Card (boom under 11m)',
          category: SiteTicketCategory.licence,
          sortOrder: 10,
        ),
      ];
      final grouped = groupTicketsByCategory(rows);
      expect(grouped.keys.first, SiteTicketCategory.induction);
      expect(grouped[SiteTicketCategory.licence]!.map((t) => t.slug).toList(), [
        'ewp_yellow_card',
        'dogging',
      ]);
    });

    test('drops empty categories so no header renders alone', () {
      final grouped = groupTicketsByCategory(const [_whiteCard]);
      expect(grouped.keys.toList(), [SiteTicketCategory.induction]);
      expect(grouped.containsKey(SiteTicketCategory.transport), isFalse);
    });

    test('an empty input yields an empty map', () {
      expect(groupTicketsByCategory(const []), isEmpty);
    });
  });
}
