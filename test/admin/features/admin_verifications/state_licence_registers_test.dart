import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/admin/features/admin_verifications/data/state_licence_registers.dart';

void main() {
  group('licenceRegisterFor', () {
    test('returns the NSW regulator + official URL for NSW', () {
      final r = licenceRegisterFor('NSW');
      expect(r, isNotNull);
      expect(r!.regulator, 'NSW Fair Trading');
      expect(r.url, contains('fairtrading.nsw.gov.au'));
    });

    test('is case-insensitive', () {
      expect(licenceRegisterFor('qld')?.regulator, 'QBCC');
    });

    test('covers all 8 states/territories', () {
      for (final s in ['NSW', 'VIC', 'QLD', 'SA', 'WA', 'TAS', 'ACT', 'NT']) {
        final r = licenceRegisterFor(s);
        expect(r, isNotNull, reason: '$s missing');
        expect(r!.url.startsWith('https://'), isTrue, reason: '$s bad url');
      }
    });

    test('returns null for null or unknown state', () {
      expect(licenceRegisterFor(null), isNull);
      expect(licenceRegisterFor('ZZ'), isNull);
      expect(licenceRegisterFor(''), isNull);
    });
  });
}
