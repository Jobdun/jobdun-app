import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/data/models/site_ticket_model.dart';
import 'package:jobdun/features/profile/domain/entities/site_ticket.dart';

void main() {
  group('SiteTicketModel.fromJson', () {
    test('parses a verifiable ticket (white_card carries a doc_type)', () {
      final t = SiteTicketModel.fromJson(const {
        'slug': 'white_card',
        'short_name': 'White Card',
        'display_name': 'White Card (Construction Induction, CPCCWHS1001)',
        'category': 'induction',
        'doc_type': 'white_card',
        'sort_order': 10,
      });
      expect(t.slug, 'white_card');
      expect(t.shortName, 'White Card');
      expect(t.category, SiteTicketCategory.induction);
      expect(t.isVerifiable, isTrue);
    });

    test('a null doc_type means self-declared only, no upload nudge', () {
      final t = SiteTicketModel.fromJson(const {
        'slug': 'dogging',
        'short_name': 'Dogging',
        'display_name': 'Dogging Licence (DG)',
        'category': 'licence',
        'doc_type': null,
        'sort_order': 30,
      });
      expect(t.docType, isNull);
      expect(t.isVerifiable, isFalse);
    });

    test('an empty doc_type is not verifiable either', () {
      final t = SiteTicketModel.fromJson(const {
        'slug': 'x',
        'short_name': 'X',
        'display_name': 'X',
        'category': 'safety',
        'doc_type': '',
      });
      expect(t.isVerifiable, isFalse);
    });

    test('an unknown category falls back instead of throwing', () {
      final t = SiteTicketModel.fromJson(const {
        'slug': 'mystery',
        'short_name': 'Mystery',
        'display_name': 'Mystery',
        'category': 'not_a_category',
        'sort_order': 0,
      });
      expect(t.category, SiteTicketCategory.safety);
    });

    test('missing sort_order defaults to 0', () {
      final t = SiteTicketModel.fromJson(const {
        'slug': 'first_aid',
        'short_name': 'First Aid',
        'display_name': 'First Aid (HLTAID011)',
        'category': 'safety',
      });
      expect(t.sortOrder, 0);
    });
  });

  group('SiteTicketCategory', () {
    test('every db value round-trips', () {
      for (final c in SiteTicketCategory.values) {
        expect(SiteTicketCategory.fromDb(c.dbValue), c);
      }
    });

    test('db values match the CHECK constraint exactly', () {
      expect(SiteTicketCategory.values.map((c) => c.dbValue).toList(), [
        'induction',
        'safety',
        'licence',
        'transport',
      ]);
    });

    test('labels are the sheet group headers', () {
      expect(SiteTicketCategory.induction.label, 'Induction');
      expect(SiteTicketCategory.safety.label, 'Safety');
      expect(SiteTicketCategory.licence.label, 'Licences');
      expect(SiteTicketCategory.transport.label, 'Transport');
    });
  });
}
