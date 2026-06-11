import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jobdun/features/profile/data/models/profile_patch_mappers.dart';
import 'package:jobdun/features/profile/domain/entities/profile_patches.dart';

void main() {
  group('tradeProfilePatchColumns', () {
    test('omits untouched fields entirely (null-wipe regression)', () {
      const patch = TradeProfilePatch(
        hourlyRateMin: Some(55.0),
        hourlyRateMax: Some(95.0),
        hourlyRateVisible: Some(true),
      );
      final map = tradeProfilePatchColumns(patch);
      expect(map, {
        'hourly_rate_min': 55.0,
        'hourly_rate_max': 95.0,
        'hourly_rate_visible': true,
      });
      // The dangerous bug: untouched columns must be ABSENT, not null.
      expect(map.containsKey('about'), isFalse);
      expect(map.containsKey('base_suburb'), isFalse);
      expect(map.containsKey('full_name'), isFalse);
    });

    test('some(null) clears a nullable column', () {
      const patch = TradeProfilePatch(basePostcode: Some(null));
      expect(tradeProfilePatchColumns(patch), {'base_postcode': null});
    });

    test('availableFrom serialises to ISO-8601, none stays absent', () {
      final patch = TradeProfilePatch(
        isAvailable: const Some(false),
        availableFrom: Some(DateTime.utc(2026, 7, 1)),
      );
      final map = tradeProfilePatchColumns(patch);
      expect(map['is_available'], false);
      expect(map['available_from'], '2026-07-01T00:00:00.000Z');
      expect(map.containsKey('hourly_rate_min'), isFalse);
    });

    test('isEmpty short-circuits', () {
      expect(const TradeProfilePatch().isEmpty, isTrue);
      expect(const TradeProfilePatch(about: Some('hi')).isEmpty, isFalse);
    });
  });

  group('userProfilePatchColumns', () {
    test('maps displayName only when set', () {
      expect(
        userProfilePatchColumns(
          const UserProfilePatch(displayName: Some('Ken')),
        ),
        {'display_name': 'Ken'},
      );
      expect(userProfilePatchColumns(const UserProfilePatch()), isEmpty);
    });
  });

  group('builderProfilePatchColumns', () {
    test('maps set fields, omits the rest', () {
      const patch = BuilderProfilePatch(
        companyName: Some('Pinnacle Construct'),
        website: Some(null),
      );
      expect(builderProfilePatchColumns(patch), {
        'company_name': 'Pinnacle Construct',
        'website': null,
      });
    });

    test('isEmpty short-circuits', () {
      expect(const BuilderProfilePatch().isEmpty, isTrue);
      expect(const BuilderProfilePatch(abn: Some('123')).isEmpty, isFalse);
    });
  });
}
