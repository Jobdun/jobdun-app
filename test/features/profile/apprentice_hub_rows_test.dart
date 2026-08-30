import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/presentation/pages/profile_edit_hub_page.dart';

void main() {
  group('hubSectionsForTrade', () {
    test('a qualified tradie sees Rates and Tickets, in that order', () {
      final s = hubSectionsForTrade(isApprentice: false);
      expect(s, contains(ProfileSection.rates));
      expect(s, contains(ProfileSection.tickets));
      expect(
        s.indexOf(ProfileSection.rates),
        lessThan(s.indexOf(ProfileSection.tickets)),
      );
    });

    test('an apprentice loses Rates but keeps Tickets', () {
      final s = hubSectionsForTrade(isApprentice: true);
      expect(s, isNot(contains(ProfileSection.rates)));
      expect(s, contains(ProfileSection.tickets));
    });

    test('Tickets shows for every trade, apprentice or not', () {
      for (final v in [true, false]) {
        expect(
          hubSectionsForTrade(isApprentice: v),
          contains(ProfileSection.tickets),
          reason: 'isApprentice=$v',
        );
      }
    });

    test('Business never appears for a trade', () {
      for (final v in [true, false]) {
        expect(
          hubSectionsForTrade(isApprentice: v),
          isNot(contains(ProfileSection.business)),
        );
      }
    });

    test('identity leads and about closes, for both modes', () {
      for (final v in [true, false]) {
        final s = hubSectionsForTrade(isApprentice: v);
        expect(s.first, ProfileSection.identity);
        expect(s.last, ProfileSection.about);
      }
    });

    test('no section is listed twice', () {
      for (final v in [true, false]) {
        final s = hubSectionsForTrade(isApprentice: v);
        expect(s.toSet().length, s.length);
      }
    });

    test('an apprentice gets a Resume row, a qualified tradie does not', () {
      // A qualified tradie quotes; they don't send a CV. Showing the row to
      // everyone would put a permanently-blank section on their profile.
      expect(
        hubSectionsForTrade(isApprentice: true),
        contains(ProfileSection.resume),
      );
      expect(
        hubSectionsForTrade(isApprentice: false),
        isNot(contains(ProfileSection.resume)),
      );
    });

    test('apprentice swaps Rates for Resume, keeping everything else', () {
      final tradie = hubSectionsForTrade(isApprentice: false);
      final apprentice = hubSectionsForTrade(isApprentice: true);
      expect(
        apprentice.where((s) => s != ProfileSection.resume),
        tradie.where((s) => s != ProfileSection.rates),
      );
    });
  });
}
